#!/bin/bash
set -x

docker pull scylladb/scylla:latest
docker pull cassandra:latest

docker stop scylla-spark
docker stop cassandra-spark

docker rm scylla-spark
docker rm cassandra-spark

#EXPOSE 10000 9042 9160 9180 7000 7001 22
#--hostname some-scylla
docker run --name scylla-spark -p 10001:10000 -p 24:22 -p 7004:7000 -p 7005:7001 -p 9181:9180 -p 9044:9042 -p 9162:9160 -d scylladb/scylla:latest

# 7000: intra-node communication
# 7001: TLS intra-node communication
# 7199: JMX
# 9042: CQL
# 9160: thrift service
#EXPOSE 7000 7001 7199 9042 9160
# --network some-network
docker run --name cassandra-spark -p 7002:7000 -p 7003:7001 -p 7200:7199 -p 9043:9042 -p 9161:9160 -d cassandra:latest



docker start scylla-spark

docker start cassandra-spark
