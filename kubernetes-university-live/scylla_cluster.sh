#!/bin/bash

. ./init.sh

wait "Deploy Scylla cluster"
kubectl apply -f cluster.yaml
kubectl -n scylla rollout status statefulset.apps/scylla-cluster-us-west1-us-west1-c

wait "Run cassandra-stress CQL traffic"
kubectl apply -f cassandra-stress.yaml

echo "Observe Grafana for traffic metrics"
