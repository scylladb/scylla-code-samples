#!/bin/bash

. ./init.sh

GCP_REGION="us-west1"
GCP_ZONE="us-west1-b"

echo 'sed "s/<gcp_region>/${GCP_REGION}/g;s/<gcp_zone>/${GCP_ZONE}/g" cluster.yaml | kubectl apply -f -'
sed "s/<gcp_region>/${GCP_REGION}/g;s/<gcp_zone>/${GCP_ZONE}/g" cluster.yaml | kubectl apply -f -

wait "\nWhat does the operator logs say? Is it doing anything?"
echo "kubectl -n scylla-operator-system logs scylla-operator-controller-manager-0"
kubectl -n scylla-operator-system logs scylla-operator-controller-manager-0

wait "\nWhat about the Scylla deployment? Did it take?"
echo "kubectl get pods -n scylla"
kubectl get pods -n scylla

wait "\nIt looks ok. What about the scylla logs"
echo "kubectl -n scylla logs scylla-cluster-us-west1-b-us-west1-0 scylla"
kubectl -n scylla logs scylla-cluster-us-west1-b-us-west1-0 scylla