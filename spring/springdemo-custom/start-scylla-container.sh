#!/bin/bash
set -x

docker pull scylladb/scylla:latest

docker rm scylla-spring

#EXPOSE 10000 9042 9160 9180 7000 7001 22
#--hostname some-scylla
docker run --name scylla-spring -p 10000:10000 -p 24:22 -p 7000:7000 -p 7001:7001 -p 9180:9180 -p 9042:9042 -p 9160:9160 -d scylladb/scylla:latest

docker start scylla-spring