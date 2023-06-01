General info and prerequisites
==============================
In this example we demonstrate an efficient parallel full table scan, that utilizes ScyllaDB architecture
to gain servers and cores parallelism optimization.

Following setup was used in this example:
- Scylla cluster v6.1: 3 x Ubuntu 24 nodes deployed on Google Compute Engine (GCE), each has 8 vCPUs and 30GB memory
- Storage: each node has 2 x 375GB local SSDs (NVMe) disks  
- Client: Ubuntu 24 node deployed on GCE (4 vCPU and 15GB memory) will run our golang code using gocql driver
- Client prerequisites:
	- Install go 1.23 * (see instructions below for sample local install, or use your OS package manager to get recent go)
	- Install prerequisites using "go mod tidy"

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

Note that query template used %s to replace token as string(in case of uuid), if token will be other type (e.g. decimal) you might need to use %d to provide it.

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
  -l, --cql-version="3.3.1"     The CQL version to use
  -p, --cluster-page-size=5000  Page size of results
  -q, --query-template="SELECT token(key) FROM keyspace1.standard1 WHERE token(key) >= %s AND token(key) <= %s;"
                                The template of the query to run. Make sure to have 2 '%s' parameters in it to embed
                                the token ranges (or use %d in case of decimal token)
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
CQL Version                   : 3.3.1
Page size                     : 5000
Query template                : SELECT token(key) FROM keyspace1.standard1 WHERE token(key) >= %s AND token(key) <= %s;
Select Statements Output file : /tmp/select_statements.txt
# of parallel threads         : 72
# of ranges to be executed    : 7200

Print Rows                    : false
Print Rows Output File        : /tmp/rows.txt


Done!

Total Execution Time: 15m32s
```



Example how to run the script
=============================

Warning: For proper installation refer to https://go.dev/doc/install
Below is really just a local sample that installs all in ~ of the user used.

E.g. for go 1.23.1:

```
GOVERSION=go1.23.1
curl -o ~/$GOVERSION.linux-amd64.tar.gz https://dl.google.com/go/$GOVERSION.linux-amd64.tar.gz

tar xzv -C ~ -f $GOVERSION.linux-amd64.tar.gz

ln -s $HOME/go $HOME/$GOVERSION 

cat <<EOF > ~/go_profile.sh
#!/bin/bash
export GOVERSION=$GOVERSION

export GOROOT=\$HOME/\$GOVERSION

export PATH=\$PATH:\$HOME/\$GOVERSION/bin
EOF

chmod 755 ~/go_profile.sh
. ~/go_profile.sh

mkdir ~/gocqlcount

cd ~/gocqlcount

curl -o efficient_full_table_scan.go https://raw.githubusercontent.com/scylladb/scylla-code-samples/master/efficient_full_table_scan_example_code/efficient_full_table_scan.go

go mod init gocqlcount

go mod tidy

```

Example full scan count using quorum for a composite primary key (PK) table (in template always use the composite PK, clustering key (CK) shall not be there),
for a cluster with 12 nodes and we only want to make 3 cpus busy per single node,
original key is ala "PRIMARY KEY ((postid, bucket), sortcolumn)" :
```
. ~/go_profile.sh
cd ~/gocqlcount
go run `pwd`/efficient_full_table_scan.go --consistency localquorum --username read_user --password read_user_password 10.240.0.29 -q "SELECT token(postid, bucket) FROM post.bucket_by_user_and_post WHERE token(postid, bucket) >= %s AND token(postid, bucket) <= %s;" -n 12 -c 3
```
