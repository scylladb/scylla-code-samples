package main

import (
    "flag"
    "time"
    "log"
    "billy"
    "sync"
    "sync/atomic"
    "golang.org/x/text/language"
    "golang.org/x/text/message"
)

type result struct {
    okRows       uint64
    failedRows   uint64
    rpcFailures  uint64
}

func executeRPC(acc *sync.WaitGroup, client *billy.Client, rpcData <-chan billy.WriteParams, totals *result, abortFailure bool) {
    defer acc.Done()
    for params := range rpcData {
        var reply billy.WriteResult
        err := client.Client.Call("RpcTask.DoPopulation", params, &reply)
        if err != nil {
            log.Fatal("RPC failed for host ", client.Host, " : ", err);
            atomic.AddUint64(&totals.rpcFailures, 1)
        } else {
            atomic.AddUint64(&totals.okRows, reply.OkRows)
            atomic.AddUint64(&totals.failedRows, reply.FailedRows)
            if reply.FailedRows > 0 && abortFailure {
                log.Fatal(reply.FailedRows, " failed rows coming from host ", client.Host, ". Aborting")
            }
        }
    }
}

func printStatus(totals result, start time.Time, phase string) {
    printer := message.NewPrinter(language.English)

    end := time.Now()
    delta := float64(end.Sub(start).Nanoseconds()) / 1000000000.0
    rate := float64(totals.okRows +  totals.failedRows) / delta

    printer.Printf("%s %d seconds. Succeeded %d rows. Failed %d rows. RPC Failures: %d. Rate %.2f rows/s\n", phase, uint64(delta), totals.okRows, totals.failedRows, totals.rpcFailures, rate)
}

func main() {
    startKey     := flag.Int64("startkey", 1, "first sensor ID")
    endKey       := flag.Int64("endkey", 2, "last sensor ID")
    loopStep     := flag.Int64("step", 10000, "how many partitions to send to a single worker thread")
    startDateStr := flag.String("startdate", "2019-01-01", "date to start sweep YYYY-MM-DD")
    endDateStr   := flag.String("enddate", "2019-01-31", "date to end sweep YYYY-MM-DD")
    hostsFile    := flag.String("hosts", "hosts.txt", "file with the hosts (loaders)")
    abortFailure := flag.Bool("abortfailure", false, "if set, abort immediately if there are failures")

    flag.Parse()

    clients := billy.ConnectClients(*hostsFile)

    var totals result

    var acc sync.WaitGroup
    rpcData := make(chan billy.WriteParams)

    for _, client := range clients {
        acc.Add(1)
        go executeRPC(&acc, client, rpcData, &totals, *abortFailure)
    }

    progress := time.NewTicker(1 * time.Minute)
    defer progress.Stop()

    start := time.Now()
    go func() {
       for _ = range progress.C {
            printStatus(totals, start, "Elapsed")
       }
    }()

    go func() {
        startDate, err := time.Parse("2006-01-02", *startDateStr)
        if err != nil {
            log.Fatal("Cannot parse start date ", *startDateStr)
        }
        endDate, err := time.Parse("2006-01-02", *endDateStr)
        if err != nil {
            log.Fatal("Cannot parse end date ", *endDateStr)
        }

        for date := startDate; date.Before(endDate) || date.Equal(endDate); date = date.AddDate(0,0,1) {
            for key := *startKey; key <= *endKey; key += *loopStep {
                lastKey := billy.Min(key + *loopStep - 1, *endKey)
                rpcData <- billy.WriteParams{"billie", key, lastKey, date}
            }
        }
        close(rpcData)
    }()
    acc.Wait()

    printStatus(totals, start, "Finished loading")
}

