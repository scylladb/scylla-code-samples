#!/bin/bash

. ./init.sh

GCP_REGION="us-west1"
GCP_ZONE="us-west1-b"

echo "kubectl apply -f operator.yaml"
kubectl apply -f operator.yaml

sleep 2

echo -ne "\nLet's look a little at the Operator deployment"
echo "kubectl get pods -n scylla-operator-system"
kubectl get pods -n scylla-operator-system