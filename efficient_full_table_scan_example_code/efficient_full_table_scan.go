package main

import (
	"fmt"
	"math"
	"math/rand"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gocql/gocql"
	"gopkg.in/alecthomas/kingpin.v2"
)

const (
	defaultNumberOfNodesInCluster     = 3
	defaultNumberOfCoresInNode        = 8
	defaultSmudgeFactor               = 3
	defaultQueryTemplate              = "SELECT token(key) FROM keyspace1.standard1 WHERE token(key) >= %s AND token(key) <= %s;"
	defaultSelectStatementsOutputFile = "/tmp/select_statements.txt"
	defaultPrintRowsOutputFile        = "/tmp/rows.txt"
)

// Modify the query for the relevant keyspace.table_name you wish to scan
// We recommend selecting only required columns, as this can eliminate unnecessary network traffic and processing
var (
	clusterHosts = kingpin.Arg("hosts", "Your Scylla nodes IP addresses, comma separated (i.e. 192.168.1.1,192.168.1.2,192.168.1.3)").Required().String()

	nodesInCluster        = kingpin.Flag("nodes-in-cluster", "Number of nodes in your Scylla cluster").Short('n').Default(fmt.Sprintf("%d", defaultNumberOfNodesInCluster)).Int()
	coresInNode           = kingpin.Flag("cores-in-node", "Number of cores in each node").Short('c').Default(fmt.Sprintf("%d", defaultNumberOfCoresInNode)).Int()
	smudgeFactor          = kingpin.Flag("smudge-factor", "Yet another factor to make parallelism cooler").Short('s').Default(fmt.Sprintf("%d", defaultSmudgeFactor)).Int()
	clusterConsistency    = kingpin.Flag("consistency", "Cluster consistency level. Use 'localone' for multi DC").Short('o').Default("one").String()
	clusterTimeout        = kingpin.Flag("timeout", "Maximum duration for query execution in millisecond").Short('t').Default("15000").Int()
	clusterNumConnections = kingpin.Flag("cluster-number-of-connections", "Number of connections per host per session (in our case, per thread)").Short('b').Default("1").Int()
	clusterCQLVersion     = kingpin.Flag("cql-version", "The CQL version to use").Short('l').Default("3.0.0").String()
	clusterPageSize       = kingpin.Flag("cluster-page-size", "Page size of results").Short('p').Default("5000").Int()

	queryTemplate              = kingpin.Flag("query-template", "The template of the query to run. Make sure to have 2 '%d' parameters in it to embed the token ranges").Short('q').Default(defaultQueryTemplate).String()
	selectStatementsOutputFile = kingpin.Flag("select-statements-output-file", "Location of select statements output file").Default(defaultSelectStatementsOutputFile).String()

	printRows           = kingpin.Flag("print-rows", "Print the output rows to a file").Short('d').Default("false").Bool()
	printRowsOutputFile = kingpin.Flag("print-rows-output-file", "Output file that will contain the printed rows").Default(defaultPrintRowsOutputFile).String()

	userName            = kingpin.Flag("username", "Username to use when connecting to the cluster").String()
	password            = kingpin.Flag("password", "Password to use when connecting to the cluster").String()

	numberOfParallelClientThreads = 1 // the calculated number of parallel threads the client should run

)

type tokenRange struct {
	StartRange int64
	EndRange   int64
}

// Calculates the token range values to be executed in parallel
func getTokenRanges() []*tokenRange {
	var n = numberOfParallelClientThreads
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

func getConsistencyLevel(consistencyValue string) gocql.Consistency {
	switch consistencyValue {
	case "any":
		return gocql.Any
	case "one":
		return gocql.One
	case "two":
		return gocql.Two
	case "three":
		return gocql.Three
	case "quorum":
		return gocql.Quorum
	case "all":
		return gocql.All
	case "localquorum":
		return gocql.LocalQuorum
	case "eachquorum":
		return gocql.EachQuorum
	case "localone":
		return gocql.LocalOne
	default:
		return gocql.One
	}
}

func main() {
	kingpin.Parse()

	numberOfParallelClientThreads = (*nodesInCluster) * (*coresInNode) * (*smudgeFactor) // the calculated number of parallel threads the client should run

	var totalRows uint64
	var ranges = getTokenRanges()
	shuffle(ranges)

	//Cluster IPs and other variables
	hosts := strings.Split(*clusterHosts, ",")

	cluster := gocql.NewCluster(hosts...)
	cluster.Consistency = getConsistencyLevel(*clusterConsistency)
	cluster.Timeout = time.Duration(*clusterTimeout * 1000 * 1000)
	cluster.NumConns = *clusterNumConnections
	cluster.CQLVersion = *clusterCQLVersion
	cluster.PageSize = *clusterPageSize

	if (*userName != "") {
		cluster.Authenticator = gocql.PasswordAuthenticator{
			Username: *userName,
			Password: *password,
		}
	}

	runParameters := fmt.Sprintf(`
Execution Parameters:
=====================

Scylla cluster nodes          : %s
Consistency                   : %s
Timeout (ms)                  : %d
Connections per host          : %d
CQL Version                   : %s
Page size                     : %d
Query template                : %s
Select Statements Output file : %s
# of parallel threads         : %d
# of ranges to be executed    : %d

Print Rows                    : %t
Print Rows Output File        : %s

`, *clusterHosts, *clusterConsistency, cluster.Timeout/1000/1000, *clusterNumConnections, *clusterCQLVersion, *clusterPageSize, *queryTemplate, *selectStatementsOutputFile, numberOfParallelClientThreads, len(ranges), *printRows, *printRowsOutputFile)

	fmt.Println(runParameters)

	startTime := time.Now().UTC()

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

	wg.Add(numberOfParallelClientThreads)
	sessionCreationWaitGroup.Add(numberOfParallelClientThreads)

	var printOutChannel chan int64
	// Only create the print out goroutine if printRows == true
	if *printRows {
		// List of returned values from the queries
		printOutChannel = make(chan int64)
		go func() {
			if f, err := os.Create(*printRowsOutputFile); err == nil {
				defer f.Close()

				for tokenKey := range printOutChannel {
					f.Write([]byte(fmt.Sprintf("%d\n", tokenKey)))
				}
			}
		}()
	}

	// Output file to see full list of queries per token range
	selectStatementOutChannel := make(chan string)
	go func() {
		if f, err := os.Create(*selectStatementsOutputFile); err == nil {
			defer f.Close()

			for statement := range selectStatementOutChannel {
				f.Write([]byte(fmt.Sprintf("%s\n", statement)))
			}
		}
	}()

	for i := 0; i < numberOfParallelClientThreads; i++ {
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
				preparedQueryString := fmt.Sprintf(*queryTemplate, "?", "?")
				preparedQuery := session.Query(preparedQueryString);

				// Read ranges from the channel, until we have completed accessing all ranges
				for r := range rangesChannel {
					query := fmt.Sprintf(*queryTemplate, r.StartRange, r.EndRange)
					preparedQuery.Bind(r.StartRange, r.EndRange)

					selectStatementOutChannel <- query

					iter := preparedQuery.Iter();

					var tokenKey int64
					var rowsRetrieved uint64
					for iter.Scan(&tokenKey) {
						if *printRows {
							// Send the tokenKey to the channel to print it into a file
							printOutChannel <- tokenKey
						}

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

	if *printRows {
		close(printOutChannel)
	}
	close(selectStatementOutChannel)
	
	if *printRows {
		// Sleep for 10 seconds to make sure the print out goroutine 
		// completes writing all lines to the output file
		time.Sleep(time.Second * 10)
	}

	totalRowsFinal := atomic.LoadUint64(&totalRows)

	fmt.Printf("Done!\n\n")
	fmt.Printf("Total Execution Time: %s\n\n", time.Since(startTime))
	fmt.Printf("Total Scanned Token Ranges : %d\n", len(ranges))
	fmt.Printf("Total Returned Partitions  : %d\n", totalRowsFinal)
}
