#!/bin/bash

. ./init.sh

GCP_REGION="us-west1"
GCP_ZONE="us-west1-b"

# Cassandra stress showcase

echo "kubectl apply -f cassandra-stress.yaml"
kubectl apply -f cassandra-stress.yaml

sleep 4

echo "kubectl get pods | grep cassandra"
kubectl get pods | grep cassandra