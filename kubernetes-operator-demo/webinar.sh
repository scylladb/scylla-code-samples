#!/bin/bash

# GENERATE DASHBOARDS!!
# examples> ./dashboards.sh -t gke

function wait() {
  echo -ne "$1"
  while [ true ] ; do
    read -t 10 -n 1
    if [ $? = 0 ] ; then
      return
    fi
  done
}

GCP_REGION="us-west1"
GCP_ZONE="us-west1-b"

wait "First we need to deploy the Scylla Operator"
echo "kubectl apply -f operator.yaml"
kubectl apply -f operator.yaml

wait "\nLet's look a little at the Operator deployment"
echo "kubectl get pods -n scylla-operator-system"
kubectl get pods -n scylla-operator-system

wait "\n"
wait "The Operator logs can also be of interest"
echo "kubectl -n scylla-operator-system logs scylla-operator-controller-manager-0"
kubectl -n scylla-operator-system logs scylla-operator-controller-manager-0

wait "\nNow it is time to deploy a Scylla Cluster"
echo 'sed "s/<gcp_region>/${GCP_REGION}/g;s/<gcp_zone>/${GCP_ZONE}/g" cluster.yaml | kubectl apply -f -'
sed "s/<gcp_region>/${GCP_REGION}/g;s/<gcp_zone>/${GCP_ZONE}/g" cluster.yaml | kubectl apply -f -

wait "\nWhat does the operator logs say? Is it doing anything?"
echo "kubectl -n scylla-operator-system logs scylla-operator-controller-manager-0"
kubectl -n scylla-operator-system logs scylla-operator-controller-manager-0

wait "\nWhat about the Scylla deployment? Did it take?"
echo "kubectl get pods -n scylla"
kubectl get pods -n scylla

wait "\nIt looks ok. What about the scylla logs?"
echo "kubectl -n scylla logs scylla-cluster-us-west1-b-us-west1-0 scylla"
kubectl -n scylla logs scylla-cluster-us-west1-b-us-west1-0 scylla

# Monitoring setup

wait "\nWe need monitoring!"
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
wait "\nWe want to be able to see the monitoring panels - Port forwarding to the rescue"
echo "New terminal needed..."
echo 'export POD_NAME=$(kubectl get pods --namespace monitoring -l "app.kubernetes.io/instance=scylla-graf" -o jsonpath="{.items[0].metadata.name}")'
export POD_NAME=$(kubectl get pods --namespace monitoring -l "app.kubernetes.io/instance=scylla-graf" -o jsonpath="{.items[0].metadata.name}")
echo "kubectl --namespace monitoring port-forward $POD_NAME 3000 > /dev/null 2>&1 &"
kubectl --namespace monitoring port-forward $POD_NAME 3000 > /dev/null 2>&1 &
sleep 5
wait "Open Grafana web UI"
xdg-open "http://0.0.0.0:3000/d/overview-4-0/overview?refresh=5s&orgId=1&from=now-30m&to=now"

# Scale up - while stressing the system...
wait "Let's scale up the cluster size..."
echo "kubectl -n scylla edit clusters.scylla.scylladb.com scylla-cluster"
kubectl -n scylla edit clusters.scylla.scylladb.com scylla-cluster
wait "\nHow many scylla pods do we get now?"
echo "kubectl get pods -n scylla"
kubectl get pods -n scylla
sleep 10
kubectl get pods -n scylla

# Upgrade Scylla - while stressing the system...
wait "Let's upgrade to Scylla 4.0.1"
echo "kubectl -n scylla edit clusters.scylla.scylladb.com scylla-cluster"
kubectl -n scylla edit clusters.scylla.scylladb.com scylla-cluster
kubectl get pods -n scylla
sleep 10
kubectl get pods -n scylla

# Cassandra stress showcase

wait "Let's put some load on it with cassandra-stress"
echo "kubectl apply -f cassandra-stress.yaml"
kubectl apply -f cassandra-stress.yaml
wait "How many jobs?"
echo "kubectl get pods | grep cassandra"
kubectl get pods | grep cassandra
