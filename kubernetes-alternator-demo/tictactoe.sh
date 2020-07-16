#!/bin/bash

. ./init.sh

GCP_REGION="us-west1"
GCP_ZONE="us-west1-b"

echo "kubectl -n scylla apply -f tictactoe.yaml"
kubectl -n scylla apply -f tictactoe.yaml

wait "What does the application startup logs say?"
echo 'kubectl logs -n scylla $(kubectl get pods -n scylla  -l "game=tictactoe" -o jsonpath="{.items[0].metadata.name}") tictactoe'
kubectl logs -n scylla $(kubectl get pods -n scylla  -l "game=tictactoe" -o jsonpath="{.items[0].metadata.name}") tictactoe

wait "What IP did we get?"
kubectl -n scylla get ingress tictactoe-ingress -o yaml

echo "Let's wait until the service is properly routed"

until kubectl -n scylla get service tictactoe -o json | jq '.status.loadBalancer.ingress[0].ip' | tr -d '"' | grep -v null; do sleep 2; echo "Still no IP assigned"; done

IP=$(kubectl -n scylla get service tictactoe -o json | jq '.status.loadBalancer.ingress[0].ip' | tr -d '"')

until curl http://${IP}/ 2>/dev/null | grep Amazon > /dev/null; do sleep 10; echo "App is not exposed yet"; done

wait "Let's open browser at http://${IP}/"

xdg-open "http://${IP}/"
