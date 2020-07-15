#!/bin/bash

. ./init.sh

GCP_REGION="us-west1"
GCP_ZONE="us-west1-b"

# Monitoring setup

echo "kubectl create namespace monitoring"
kubectl create namespace monitoring
wait "Deploy prometheus since that is what Scylla uses"
echo "helm upgrade --install scylla-prom --namespace monitoring stable/prometheus -f prometheus/values.yaml"
helm upgrade --install scylla-prom --namespace monitoring stable/prometheus -f prometheus/values.yaml
wait "What did the prometheus chart actually deploy?"
echo "kubectl get pods -n monitoring"
kubectl get pods -n monitoring
wait "\nLet's deploy Grafana as well so we can actually have some graphs"
echo "helm upgrade --install scylla-graf --namespace monitoring stable/grafana -f grafana/values.yaml"
helm upgrade --install scylla-graf --namespace monitoring stable/grafana -f grafana/values.yaml
echo "What did the grafana chart deploy?"
wait "kubectl get pods -n monitoring"
kubectl get pods -n monitoring