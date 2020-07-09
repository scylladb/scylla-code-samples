#!/bin/bash

# Delete the application
kubectl -n scylla delete -f tictactoe.yaml

# Delete the scylla cluster
sed "s/<gcp_region>/${GCP_REGION}/g;s/<gcp_zone>/${GCP_ZONE}/g" cluster.yaml | kubectl delete -f -

# Delete monitoring stack
helm uninstall scylla-graf --namespace monitoring
helm uninstall scylla-prom --namespace monitoring
kubectl delete namespace monitoring

# Delete the operator
kubectl delete -f operator.yaml

killall kubectl