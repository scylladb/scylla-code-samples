#!/bin/bash

. ./init.sh

GCP_REGION="us-west1"
GCP_ZONE="us-west1-b"

./cassandra-stress.sh 1 > /dev/null 2>&1 &

wait "First we need monitoring"
./monitoring.sh --non-interactive

wait "Now we need to deploy the Scylla Operator"
./operator.sh --non-interactive

wait "\nNow it is time to deploy a Scylla Cluster"
./cluster.sh

wait "Let's put some load on it with cassandra-stress"
./cassandra-stress.sh

wait "stress can take a while to start.."
wait "Let's scale down the cluster size"
./edit-cluster.sh