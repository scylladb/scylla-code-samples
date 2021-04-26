#!/bin/bash

. ./init.sh

wait "Deploy Alternator cluster"
kubectl apply -f alternator.yaml
kubectl -n scylla rollout status statefulset.apps/scylla-cluster-us-west1-us-west1-b

wait "Run TickTackToe game"
kubectl apply -f ticktacktoe.yaml

echo "Check `kubectl -n ticktacktoe get svc' for ExternalIP address of a game, it may take some time before it is assigned"
