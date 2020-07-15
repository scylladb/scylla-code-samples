#!/bin/bash

. ./init.sh

GCP_REGION="us-west1"
GCP_ZONE="us-west1-b"

wait "First we need monitoring"
./monitoring.sh --non-interactive

wait "Now we need to deploy the Scylla Operator"
./operator.sh --non-interactive

wait "\nNow it is time to deploy a Scylla Cluster"
./cluster.sh

echo "Let's deploy an application: Tic Tac Toe"
wait "The ingress can take a while to route everything.."
./tictactoe.sh

wait "Let's scale down the cluster size"
./edit-cluster.sh