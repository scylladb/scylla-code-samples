#!/bin/bash
set -x

docker pull scylladb/scylla:4.4.3

docker rm scylla-spark

#EXPOSE 10000 9042 9160 9180 7000 7001 22
#--hostname some-scylla
docker run --name scylla-spark -p 10001:10000 -p 24:22 -p 7004:7000 -p 7005:7001 -p 9181:9180 -p 9044:9042 -p 9162:9160 -d scylladb/scylla:4.4.3

docker start scylla-spark

