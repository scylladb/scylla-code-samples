#!/bin/bash

. ./init.sh

GCP_REGION="us-west1"
GCP_ZONE="us-west1-b"

# Launch Grafana Web UI

killall kubectl 1>/dev/null 2>&1

wait "\nWe want to be able to see the monitoring panels - Port forwarding to the rescue"
echo 'export POD_NAME=$(kubectl get pods --namespace monitoring -l "app.kubernetes.io/instance=scylla-graf" -o jsonpath="{.items[0].metadata.name}")'
export POD_NAME=$(kubectl get pods --namespace monitoring -l "app.kubernetes.io/instance=scylla-graf" -o jsonpath="{.items[0].metadata.name}")
echo "kubectl --namespace monitoring port-forward $POD_NAME 3000 > /dev/null 2>&1 &"
kubectl --namespace monitoring port-forward $POD_NAME 3000 > /dev/null 2>&1 &
sleep 2
wait "Open Grafana web UI"
xdg-open "http://0.0.0.0:3000/d/overview-4-0/overview?refresh=5s&orgId=1&from=now-30m&to=now"