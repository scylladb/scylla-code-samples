package main

import (
    "flag"
    "time"
    "log"
    "billy"
    "sync"
    "fmt"
    "os"
    "sort"
    "golang.org/x/text/language"
    "golang.org/x/text/message"
    "math/rand"
)

type result struct {
}

type dataPoint struct {
    date    time.Time
    average float32
    min     float32
    max     float32
    idmin   int64
    idmax   int64
}

type dataPointArray []dataPoint
func (a dataPointArray) Len() int {
    return len(a)
}

func (a dataPointArray) Less(i, j int) bool {
    return a[i].date.Before(a[j].date)
}

func (a dataPointArray) Swap(i, j int) {
    a[i], a[j] = a[j], a[i]
}

type timeArray []time.Time
func (a timeArray) Len() int {
    return len(a)
}

func (a timeArray) Less(i, j int) bool {
    return a[i].Before(a[j])
}

func (a timeArray) Swap(i, j int) {
    a[i], a[j] = a[j], a[i]
}

type resultMap struct {
    mutex sync.Mutex
    pointsMap map[time.Time]billy.ReadResult
    okRows      uint64
    failedRows  uint64
    rpcFailures uint64
}

func (r *resultMap) printResult(printer *message.Printer, elapsed time.Duration) {
    delta := float64(elapsed.Nanoseconds()) / 1000000000.0

    r.mutex.Lock()
    printer.Printf("Finished Scanning. Succeeded %d rows. Failed %d rows. RPC Failures: %d. Took %.2f ms\n", r.okRows, r.failedRows, r.rpcFailures, delta * 1000.0)
    printer.Printf("Processed %d rows/s\n", uint64(float64(r.okRows +  r.failedRows) / delta))
    r.mutex.Unlock()
}


func executeRPC(acc *sync.WaitGroup, client *billy.Client, rpcData <-chan billy.ScanParams, resultMap *resultMap, abortFailure bool) {

    defer acc.Done()
    for params := range rpcData {
        var reply billy.ReadResult

        err := client.Client.Call("RpcTask.DoScan", params, &reply);
        if err != nil {
            resultMap.mutex.Lock()
            resultMap.rpcFailures += 1
            resultMap.mutex.Unlock()
            log.Fatal("RPC failed for host ", client.Host, " : ", err);
        } else {
            resultMap.mutex.Lock()
            if current, exists := resultMap.pointsMap[params.Date]; exists {
                current.Accumulate(reply)
                resultMap.pointsMap[params.Date] = current
            } else {
                resultMap.pointsMap[params.Date] = reply
            }

            resultMap.okRows += reply.TotalRows
            resultMap.failedRows += reply.FailedRows
            resultMap.mutex.Unlock()
        }
    }
}

func (r *resultMap) mapToFile(filename string) (dataPoint, dataPoint) {
    f, err := os.Create(filename)
    if err != nil {
        log.Fatal("Can't create file ", filename)
    }

    points := dataPointArray{}
    r.mutex.Lock()
    for key, value := range r.pointsMap {
        var point dataPoint
        point.date = key
        point.average = value.TotalValue / float32(value.TotalRows)
        point.max = value.MaxValue
        point.min = value.MinValue
        point.idmin = value.SensoridMin
        point.idmax = value.SensoridMax
        points = append(points, point)
    }
    r.mutex.Unlock()

    sort.Sort(points)

    _, err = f.WriteString(fmt.Sprintf("date       avg   min   max   idmin idmax\n"))
    if err != nil {
        log.Fatal("Writing to file : ", err)
    }

    var minPoint dataPoint
    var maxPoint dataPoint

    minPoint = points[0]
    maxPoint = points[0]

    for _, point := range points {
        _, err := f.WriteString(fmt.Sprintf("%s %3.2f %3.2f %3.2f %05d %05d\n", point.date.Format("2006-01-02"), point.average, point.min, point.max, point.idmin, point.idmax))
        if err != nil {
            log.Fatal("Writing to file : ", err)
        }
        if point.min < minPoint.min {
            minPoint = point
        }
        if point.max > maxPoint.max {
            maxPoint = point
        }
    }

    defer f.Close()
    defer f.Sync()
    return minPoint, maxPoint
}

func main() {
    startKey       := flag.Int64("startkey", 1, "first sensor ID")
    endKey         := flag.Int64("endkey", 2, "last sensor ID")
    loopStep       := flag.Int64("step", 10000, "how many partitions to send to a single worker thread")
    startDateStr   := flag.String("startdate", "2019-01-01", "date to start sweep YYYY-MM-DD")
    endDateStr     := flag.String("enddate", "2019-01-31", "date to end sweep YYYY-MM-DD")
    hostsFile      := flag.String("hosts", "hosts.txt", "file with the hosts (loaders)")
    outputFile     := flag.String("output", "output.txt", "file with the datapoints")
    abortFailure   := flag.Bool("abortfailure", false, "if set, abort immediately if there are failures")
    dateVisitation := flag.String("sweep", "sequential", "how to scan the dates (sequential, random, reverse)")
    exclude        := flag.Int64("exclude", 0, "if > 0, do not scan this particular sensorID")

    flag.Parse()

    clients := billy.ConnectClients(*hostsFile)
    printer := message.NewPrinter(language.English)

    var acc sync.WaitGroup

    var resultMap resultMap
    resultMap.pointsMap = map[time.Time]billy.ReadResult{}

    rpcData := make(chan billy.ScanParams)

    for _, client := range clients {
        acc.Add(1)
        go executeRPC(&acc, client, rpcData, &resultMap, *abortFailure)
    }

    startDate, err := time.Parse("2006-01-02", *startDateStr)
    if err != nil {
        log.Fatal("Cannot parse start date ", *startDateStr)
    }
    endDate, err := time.Parse("2006-01-02", *endDateStr)
    if err != nil {
        log.Fatal("Cannot parse end date ", *endDateStr)
    }

    dates := timeArray{}
    for date := startDate; date.Before(endDate) || date.Equal(endDate); date = date.AddDate(0,0,1) {
        dates = append(dates, date)
    }
    if *dateVisitation == "sequential" {
        // ready
    }else if *dateVisitation == "reverse" {
        sort.Sort(sort.Reverse(dates))
    } else if *dateVisitation == "random" {
        rand.Seed(time.Now().UnixNano())
        rand.Shuffle(len(dates), func(i, j int) {
		    dates[i], dates[j] = dates[j], dates[i]
        })
    } else {
        log.Fatal("Invalid visitation order ", *dateVisitation)
    }

    start := time.Now()
    go func() {
        for _, date := range dates {
            for key := *startKey; key <= *endKey; key += *loopStep {
                lastKey := billy.Min(key + *loopStep - 1, *endKey)
                if *exclude != 0 && *exclude >= key && *exclude <= lastKey {
                  if *exclude - 1 >= key {
                    rpcData <- billy.ScanParams{"background", key, *exclude - 1, date}
                  }
                  if *exclude + 1 <= lastKey {
                    rpcData <- billy.ScanParams{"background", *exclude + 1, lastKey, date}
                  }
                } else {
                    rpcData <- billy.ScanParams{"background", key, lastKey, date}
                }
            }
        }
        close(rpcData)
    }()

    acc.Wait()
    end := time.Now()

    minPoint, maxPoint := resultMap.mapToFile(*outputFile)
    resultMap.printResult(printer, end.Sub(start))
    printer.Printf("Absolute min: %.2f, date %s, sensorID %s\n", minPoint.min, minPoint.date.Format("2006-01-02"), fmt.Sprintf("%d", minPoint.idmin))
    printer.Printf("Absolute max: %.2f, date %s, sensorID %s\n", maxPoint.max, maxPoint.date.Format("2006-01-02"), fmt.Sprintf("%d", maxPoint.idmax))
}

