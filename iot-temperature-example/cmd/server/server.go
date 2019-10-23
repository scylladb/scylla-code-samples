package main

import (
    "flag"
    "time"
    "log"
    "github.com/gocql/gocql"
    "net"
    "net/rpc"
    "net/http"
    "math/rand"
    "billy"
    "sync"
    "sync/atomic"
    "os"
    "syscall"
    "math"
)

// CREATE TABLE billy.readings (
//    sensor_id int,
//    date date,
//    time time,
//    temperature float,
//    PRIMARY KEY ((sensor_id, date), time, timestamp)
//) WITH bloom_filter_fp_chance = 0.01
//    AND caching = {'keys': 'ALL', 'rows_per_partition': 'ALL'}
//    AND comment = ''
//    AND compaction = {'class': 'SizeTieredCompactionStrategy'}
//    AND compression = {}
//    AND crc_check_chance = 1.0
//    AND dclocal_read_repair_chance = 0.1
//    AND default_time_to_live = 0
//    AND gc_grace_seconds = 864000
//    AND max_index_interval = 2048
//    AND memtable_flush_period_in_ms = 0
//    AND min_index_interval = 128
//    AND read_repair_chance = 0.0
//    AND speculative_retry = '99.0PERCENTILE';


type RpcTask struct {
    sessions map[string]*gocql.Session
    parallelism int
}

func accumulate(wg *sync.WaitGroup, accumChannel chan billy.ReadResult) *billy.ReadResult {
    result := new(billy.ReadResult)
    result.MinValue = math.MaxFloat32;

    var accWg sync.WaitGroup
    accWg.Add(1)
    go func() {
        defer accWg.Done()
        for res := range accumChannel {
            result.Accumulate(res)
        }
    }()

    wg.Wait()
    close(accumChannel)
    accWg.Wait()
    return result
}

func consistentBatch(session *gocql.Session) *gocql.Batch {
    b := session.NewBatch(gocql.UnloggedBatch)
    b.SetConsistency(gocql.All)
    return b
}

func writeKey(wg *sync.WaitGroup, keyChannel <-chan int64, result *billy.WriteResult,
              numRows int, date time.Time, session *gocql.Session) {

    defer wg.Done()

    maxBatch := uint64(100);
    currentBatch := uint64(0);


    day := int64(date.Sub(billy.BaseDate()).Hours() / 24)
	r := rand.New(rand.NewSource(day))

    lambda := 3.0
    min := 68 + r.ExpFloat64() / lambda

    var temperature float32
    for key := range keyChannel {

        b := consistentBatch(session)

        for i := 0; i < numRows; i++ {
            temperature = float32(r.ExpFloat64() / 1.5 + min)
            // Each row is a minute, or 60 seconds * 1000000000 nanoseconds per second
            b.Query("INSERT INTO readings (sensor_id, date, time, temperature) VALUES (?, ?, ?, ?)", key, date, int64(i) * int64(60 * 1000000000), temperature);

            currentBatch += 1;

            if ((i == numRows - 1) || (currentBatch >= maxBatch)) {
                start := time.Now()
                if err := session.ExecuteBatch(b); err != nil {
                    end := time.Now()
                    log.Printf("batch for key %d, failed: %s , took %d", key, err, end.Sub(start).Nanoseconds() / 1000000);
                    atomic.AddUint64(&result.FailedRows, currentBatch)
                } else {
                    atomic.AddUint64(&result.OkRows, currentBatch)
                }

                currentBatch = 0;
                b = consistentBatch(session)
            }
        }
    }
}

type syncRead struct {
    mutex sync.Mutex
    result billy.ReadResult
}

func readKey(wg *sync.WaitGroup, keyChannel <-chan int64, accum *syncRead, date time.Time, session *gocql.Session) {
    query := session.Query(`SELECT count(temperature) as totalRows , sum(temperature) as sumTemperature , min(temperature) as minTemperature, max(temperature) as maxTemperature from readings where sensor_id = ? and date = ?`);

    defer wg.Done()

    for pkey := range keyChannel {
        var result billy.ReadResult

        iter := query.Bind(pkey, date).Iter();

        var totalRows uint64;
        var sumTemperature float32;
        var maxTemperature float32;
        var minTemperature float32;

        sumTemperature = 1.0

        if !iter.Scan(&totalRows, &sumTemperature, &minTemperature, &maxTemperature) {
            result.FailedRows++
        } else {
            result.TotalValue = sumTemperature
            result.MinValue = minTemperature
            result.MaxValue = maxTemperature
            result.TotalRows = totalRows
            result.SensoridMin = pkey
            result.SensoridMax = pkey
        }

        if totalRows != 1440 {
            log.Fatal("Did not read 1440 rows, only ", totalRows)
        }
        accum.mutex.Lock()
        accum.result.Accumulate(result)
        accum.mutex.Unlock()

        if err := iter.Close(); err != nil {
            result.FailedRows++
            log.Printf("key (%d) failed: %s", pkey, err);
        }
    }
}

func (rpcTask *RpcTask) DoPopulation(userParams billy.WriteParams, reply *billy.WriteResult) error {
    numRows := 1440;
    keyChannel := make(chan int64)

    var wg sync.WaitGroup
    var result billy.WriteResult

    session := rpcTask.sessions[userParams.UserName]

    for j := 0; j < rpcTask.parallelism; j++ {
        wg.Add(1)
        go writeKey(&wg, keyChannel, &result, numRows, userParams.Date, session)
    }

    for i := userParams.StartKey; i <= userParams.EndKey; i++ {
        keyChannel <- i
    }
    close(keyChannel)
    wg.Wait()

    log.Println("Succeeded : ", result.OkRows, " Failed " , result.FailedRows, " Rows ")
    *reply = result
    return nil
}

func (rpcTask *RpcTask) DoScan(userParams billy.ScanParams, reply *billy.ReadResult) error {

    keyChannel := make(chan int64)

    var wg sync.WaitGroup

    session := rpcTask.sessions[userParams.UserName]

    result := new(syncRead)
    result.result.MinValue = math.MaxFloat32;

    for j := 0; j < rpcTask.parallelism; j++ {
        wg.Add(1)
        go readKey(&wg, keyChannel, result, userParams.Date, session)
    }

    for pkey := userParams.StartKey; pkey <= userParams.EndKey; pkey++ {
        keyChannel <- pkey
    }
    close(keyChannel)
    wg.Wait()

    *reply = result.result;
    return nil
}

func createSession(username string, hostNode string) *gocql.Session {
    // connect to the cluster
    cluster := gocql.NewCluster(hostNode);
    cluster.Keyspace = "billy"
    cluster.Consistency = gocql.LocalOne

    cluster.PoolConfig.HostSelectionPolicy = gocql.TokenAwareHostPolicy(gocql.RoundRobinHostPolicy());
    cluster.Timeout = 60 * time.Second
    cluster.ConnectTimeout = 5 * time.Second

    session, err := cluster.CreateSession()
    if err != nil {
        log.Fatal("Could not establish connection to ", hostNode, " with user ", username, " : ", err)
    }
    return session
}

func main() {

    parallelismPtr := flag.Int("p", 100, "parallelism")
    nodePtr := flag.String("node", "127.0.0.1", "IP of the node")
    hostPtr := flag.String("bind", "localhost:20000", "address hostname:port where to bind to")
    logFile := flag.String("logfile", "log.txt", "log file where to print the server information")

    flag.Parse()
    f, err := os.Create(*logFile)
    if err != nil {
        log.Fatal("Cant open log file. Aborting: ", err)
    }
    defer f.Close()

    log.SetOutput(f)

    log.Printf("Starting")

    var rLimit syscall.Rlimit
    rLimit.Max = 102400
    rLimit.Cur = 102400

    err = syscall.Setrlimit(syscall.RLIMIT_NOFILE, &rLimit)
    if err != nil {
        log.Fatal("Error Setting Rlimit ", err)
    }

    rpcTask := new(RpcTask)
    rpcTask.parallelism = *parallelismPtr

    rpcTask.sessions = make(map[string]*gocql.Session)
    rpcTask.sessions["billie"] = createSession("billie", *nodePtr)
    rpcTask.sessions["background"] = rpcTask.sessions["billie"]

    defer rpcTask.sessions["billie"].Close()

    err = rpc.Register(rpcTask)
    if err != nil {
        log.Fatal("Can't register RPC task : ", err)
    }
    rpc.HandleHTTP()

    listener, err := net.Listen("tcp", *hostPtr)
    if err != nil {
        log.Fatal("Can't Listen on RPC: ", err)
    } else {
        log.Println("Listening at ", *hostPtr)
    }

    err = http.Serve(listener, nil)
    if err != nil {
        log.Fatal("Error serving ", err)
    }
}
