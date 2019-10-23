package billy

import (
    "time"
    "os"
    "bufio"
    "log"
    "net/rpc"
)

func Min(x, y int64) int64 {
    if x < y {
        return x
    }
    return y
}

type ScyllaPkey struct {
    Sensorid int64
    Day      int
    Time     int64
}

type WriteResult struct {
    OkRows uint64
    FailedRows uint64
}

type ReadResult struct {
    TotalRows   uint64
    TotalValue  float32
    MinValue    float32
    MaxValue    float32
    FailedRows  uint64
    SensoridMin int64
    SensoridMax int64
}


type WriteParams struct {
    UserName string
    StartKey int64
    EndKey   int64
    Date     time.Time
}

type ScanParams struct {
    UserName string
    StartKey int64
    EndKey   int64
    Date     time.Time
}

type ReadParams struct {
    UserName string
    StartKey int64
    EndKey   int64
    Date     time.Time
    Duration int64
}

func (result *ReadResult) Accumulate(res ReadResult) {
    result.TotalRows += res.TotalRows
    result.TotalValue += res.TotalValue
    result.FailedRows += res.FailedRows
    if res.MaxValue > result.MaxValue {
        result.MaxValue = res.MaxValue
        result.SensoridMax = res.SensoridMax
    }

    if res.MinValue < result.MinValue {
        result.MinValue = res.MinValue
        result.SensoridMin = res.SensoridMin
    }
}

func fileToArray(filename string) []string {
    hosts := []string {}

    file, err := os.Open(filename)
    if err != nil {
        log.Fatal(err)
    }
    defer file.Close()

    scanner := bufio.NewScanner(file)
    for scanner.Scan() {
        hosts = append(hosts, scanner.Text())
    }

    if err := scanner.Err(); err != nil {
        log.Fatal(err)
    }

    return hosts
}

type Client struct {
    Client *rpc.Client
    Host   string
}

func ConnectClients(filename string) []*Client {
    clients := []*Client{}

    for _, host := range fileToArray(filename) {
        // Create a TCP connection to localhost on port 1234
        client, err := rpc.DialHTTP("tcp", host)
        clientInfo := new(Client)
        clientInfo.Client = client
        clientInfo.Host = host
        if err != nil {
            log.Fatal("Connection error: ", host, " : " , err)
        }
        clients = append(clients, clientInfo)
    }

    return clients
}

func BaseDate() time.Time {
    return time.Date(2019, time.Month(1), 1, 0, 0, 0, 0, time.UTC)
}
