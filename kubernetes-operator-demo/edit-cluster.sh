#!/bin/bash

. ./init.sh

GCP_REGION="us-west1"
GCP_ZONE="us-west1-b"

# Edit the cluster
echo "kubectl -n scylla edit clusters.scylla.scylladb.com scylla-cluster"
kubectl -n scylla edit clusters.scylla.scylladb.com scylla-cluster
wait "\nHow many scylla pods do we get now?"
echo "kubectl get pods -n scylla"
kubectl get pods -n scylla
sleep 10
kubectl get pods -n scylla