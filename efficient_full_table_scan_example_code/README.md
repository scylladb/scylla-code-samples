General info and prerequisites
==============================
In this example we demonstrate an efficient parallel full table scan, that utilizes ScyllaDB architecture
to gain servers and cores parallelism optimization.

Following setup was used in this example:
- Scylla cluster v1.6.1: 3 x RHEL7.2 nodes deployed on Google Compute Engine (GCE), each has 8 vCPUs and 30GB memory
- Storage: each node has 2 x 375GB local SSDs (NVMe) disks  
- Client: Centos7.2 node deployed on GCE (4 vCPU and 15GB memory) will run our golang code using gocql driver
- Client prerequisites:
	- Install go 1.7: https://www.digitalocean.com/community/tutorials/how-to-install-go-1-7-on-centos-7
	- Install gocql driver: "go get github.com/gocql/gocql"
	- Install kingpin pkg: "go get gopkg.in/alecthomas/kingpin.v2"


Instructions
============
Use the following Cassandra stress test to populate a table:
```
nohup cassandra-stress write n=47500000 cl=QUORUM -schema "replication(factor=3)" -mode native cql3 -pop seq=1..47500000 -node 10.240.0.29,10.240.0.30,10.240.0.35 -rate threads=500 -log file=output.txt
```

In order to use this code to scan a table of your own, make sure to adjust the query template to the [keyspace].[table_name] and token(key) you wish to scan.

In order to run the code and/or see the usage (--help), run the following:
```
go run $GOPATH/[full path to the go code]/efficient_full_table_scan.go [<flags>] <hosts>
```

Mandatory param: `<hosts>` = your Scylla nodes IP addresses. The rest of the params have defaults, which you can decide to adjust according to your setup and dataset.

Note: `-d` flag (default=false) prints all the rows into a file for debugging purpose. This loads the client CPU, hence use with caution.


--help usage output
===================
```
usage: efficient_full_table_scan [<flags>] <hosts>

Flags:
      --help                    Show context-sensitive help (also try --help-long and --help-man).
  -n, --nodes-in-cluster=3      Number of nodes in your Scylla cluster
  -c, --cores-in-node=8         Number of cores in each node
  -s, --smudge-factor=3         Yet another factor to make parallelism cooler
  -o, --consistency="one"       Cluster consistency level. Use 'localone' for multi DC
  -t, --timeout=15000           Maximum duration for query execution in millisecond
  -b, --cluster-number-of-connections=1
                                Number of connections per host per session (in our case, per thread)
  -l, --cql-version="3.0.0"     The CQL version to use
  -p, --cluster-page-size=5000  Page size of results
  -q, --query-template="SELECT token(key) FROM keyspace1.standard1 WHERE token(key) >= %d AND token(key) <= %d;"
                                The template of the query to run. Make sure to have 2 '%d' parameters in it to embed
                                the token ranges
      --select-statements-output-file="/tmp/select_statements.txt"
                                Location of select statements output file
  -d, --print-rows              Print the output rows to a file
      --print-rows-output-file="/tmp/rows.txt"
                                Output file that will contain the printed rows
      --username                The username to use to connect to the cluster (default: no username)
      --password                The password to use to connect to the cluster (default: no password)

Args:
  <hosts>  Your Scylla nodes IP addresses, comma separated (i.e. 192.168.1.1,192.168.1.2,192.168.1.3)
```

Output example of a run
=======================

```
Execution Parameters:
=====================

Scylla cluster nodes          : 10.240.0.29,10.240.0.30,10.240.0.35
Consistency                   : one
Timeout (ms)                  : 15000
Connections per host          : 1
CQL Version                   : 3.0.0
Page size                     : 5000
Query template                : SELECT token(key) FROM keyspace1.standard1 WHERE token(key) >= %d AND token(key) <= %d;
Select Statements Output file : /tmp/select_statements.txt
# of parallel threads         : 72
# of ranges to be executed    : 7200

Print Rows                    : false
Print Rows Output File        : /tmp/rows.txt


Done!

Total Execution Time: 15m32s
```
