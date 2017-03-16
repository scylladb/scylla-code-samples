// THIS SCRIPT ASSUMES USING A SINGLE CLIENT TO RUN THE FULL TABLE SCAN
// Prerequisite:
//  Install go 1.7: https://www.digitalocean.com/community/tutorials/how-to-install-go-1-7-on-centos-7
//  Install gocql driver: https://academy.datastax.com/resources/getting-started-apache-cassandra-and-go

package main

import (
        "fmt"
        "math"
        "math/rand"
        "os"
        "sync"
        "sync/atomic"
        "time"

        "github.com/gocql/gocql"
)

// Your Scylla cluster setup
const (
        // NodesInCluster - the number of nodes in your cluster
        NodesInCluster = 3
        // CoresInNode - the number of cores in each node
        CoresInNode = 8
        // SmudgeFactor - is a factor to add to make parallelism cooler
        SmudgeFactor = 3
        // NumberOfParallelClientThreads - the calculated number of parallel threads the client should run
        NumberOfParallelClientThreads = NodesInCluster * CoresInNode * SmudgeFactor
)

// Modify the query for the relevant keyspace.table_name you wish to scan
// We recommend selecting only required columns, as this can eliminate unnecessary network traffic and processing
var (
        queryTemplate = "SELECT token(key) FROM keyspace1.standard1 WHERE token(key) >= %d AND token(key) <= %d;"
)

type tokenRange struct {
        StartRange int64
        EndRange   int64
}

// Calculates the token range values to be executed in parallel
func getTokenRanges() []*tokenRange {
        var n = NumberOfParallelClientThreads
        var m = int64(n * 100)
        var maxSize uint64 = math.MaxInt64 * 2
        var rangeSize = maxSize / uint64(m)

        var start int64 = math.MinInt64
        var end int64
        var shouldBreak = false

        var ranges = make([]*tokenRange, m)

        for i := int64(0); i < m; i++ {
                end = start + int64(rangeSize)
                if start > 0 && end < 0 {
                        end = math.MaxInt64
                        shouldBreak = true
                }

                ranges[i] = &tokenRange{StartRange: start, EndRange: end}

                if shouldBreak {
                        break
                }

                start = end + 1
        }

        return ranges
}

// Randomize the execution of the token range statements
func shuffle(data []*tokenRange) {
        for i := 1; i < len(data); i++ {
                r := rand.Intn(i + 1)
                if i != r {
                        data[r], data[i] = data[i], data[r]
                }
        }
}

func main() {
        var totalRows uint64
        var ranges = getTokenRanges()

        shuffle(ranges)
		
		//Cluster IPs and other variables
        cluster := gocql.NewCluster("10.240.0.29", "10.240.0.30", "10.240.0.35")
        cluster.Consistency = gocql.One
        cluster.Timeout = time.Millisecond * 12000
        cluster.NumConns = 1
        cluster.CQLVersion = "3.0.0"
        cluster.PageSize = 5000

        // Create a buffered channel to send all the ranges into it.
        // The channel will be used by the goroutines to pull in ranges
        // that require running a query
        rangesChannel := make(chan *tokenRange, len(ranges))
        for i := range ranges {
                rangesChannel <- ranges[i]
        }

        // Close the channel so that the goroutines woun't get deadlocked
        close(rangesChannel)

        // Mechanism to sync all goroutines and mark when we have finished running them all
        var wg sync.WaitGroup
        var sessionCreationWaitGroup sync.WaitGroup

        wg.Add(NumberOfParallelClientThreads)
        sessionCreationWaitGroup.Add(NumberOfParallelClientThreads)
		
		
        // Output file to see full list of queries per token range
		selectStatementOutChannel := make(chan string)
        go func() {
                if f, err := os.Create("/tmp/select_statements.txt"); err == nil {
                        defer f.Close()

                        for statement := range selectStatementOutChannel {
                                f.Write([]byte(fmt.Sprintf("%s\n", statement)))
                        }
                }
        }()

        for i := 0; i < NumberOfParallelClientThreads; i++ {
                go func() {
                        defer wg.Done()

                        var session *gocql.Session
                        var err error
                        if session, err = cluster.CreateSession(); err == nil {
                                defer session.Close()

                                // Make sure we start running queries after all 
                                // goroutines have opened a session successfully
                                sessionCreationWaitGroup.Done()
                                sessionCreationWaitGroup.Wait()

                                
                                // Read ranges from the channel, until we have completed accessing all ranges
                                for r := range rangesChannel {
                                        query := fmt.Sprintf(queryTemplate, r.StartRange, r.EndRange)

                                        selectStatementOutChannel <- query

                                        iter := session.Query(query).Iter()

                                        var tokenKey int64
                                        var rowsRetrieved uint64
                                        for iter.Scan(&tokenKey) {
                                                // Send the tokenKey to the channel that will print it into a file
                                                // printOutChannel <- tokenKey
                                                rowsRetrieved++
                                        }

                                        iterError := iter.Close()
                                        if iterError != nil {
                                                fmt.Printf("ERROR: iteration failed: %s\n", iterError)
                                        }

                                        atomic.AddUint64(&totalRows, rowsRetrieved)
                                }
                        } else {
                                fmt.Printf("ERROR: %s\n", err)
                        }
                }()
        }

        wg.Wait()

        // We are done, close the printOut channel
        close(selectStatementOutChannel)
        
        totalRowsFinal := atomic.LoadUint64(&totalRows)

        fmt.Printf("Done!\n\n")
        fmt.Printf("Total Scanned Token Ranges: %d\n", len(ranges))
        fmt.Printf("Total Returned Partitions: %d\n", totalRowsFinal)
}
