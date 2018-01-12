#!/bin/bash
sleep 60
cd /opt/prometheus-2.0.0.linux-amd64
./prometheus --config.file=prometheus.yml --storage.tsdb.path /opt/prometheus-2.0.0.linux-amd64/mydata& 
service grafana-server start;
cd /opt/scylla-grafana-monitoring/;
./load-grafana.sh -p 127.0.0.1:9090 -g 3000 -a admin -v 2.0&
sleep infinity