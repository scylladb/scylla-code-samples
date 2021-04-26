### Walkthrough

1. Spin up a GKE cluster
    ```
    export GCP_USER=$(gcloud config list account --format "value(core.account)")        
    export GCP_PROJECT=$(gcloud config list project --format "value(core.project)")
    
    ./gke.sh --gcp-user "$GCP_USER" -p "$GCP_PROJECT" -c "university-live-demo"
    ```
1. Install cert-manager - Scylla Operator dependency
    ```
    kubectl apply -f cert-manager.yaml
    
    kubectl wait --for condition=established crd/certificates.cert-manager.io crd/issuers.cert-manager.io
    kubectl -n cert-manager rollout status --timeout=5m deployment.apps/cert-manager-cainjector
    kubectl -n cert-manager rollout status --timeout=5m deployment.apps/cert-manager-webhook
    ```

1. Install Scylla Operator
    ```
    kubectl apply -f operator.yaml
   
    kubectl wait --for condition=established crd/scyllaclusters.scylla.scylladb.com
    kubectl -n scylla-operator-system rollout status statefulset.apps/scylla-operator-controller-manager
    ```

1. Install Prometheus monitoring
    ```
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    helm install monitoring prometheus-community/kube-prometheus-stack --values monitoring/values.yaml --values monitoring.yaml --create-namespace --namespace scylla-monitoring
    ```

1. Install Scylla Monitoring dashboards
    ```
    wget https://github.com/scylladb/scylla-monitoring/archive/scylla-monitoring-3.6.0.tar.gz
    tar -xvf scylla-monitoring-3.6.0.tar.gz
    
    kubectl -n scylla-monitoring create configmap scylla-dashboards --from-file=scylla-monitoring-scylla-monitoring-3.6.0/grafana/build/ver_4.3
    kubectl -n scylla-monitoring patch configmap scylla-dashboards  -p '{"metadata":{"labels":{"grafana_dashboard": "1"}}}'
    
    kubectl -n scylla-monitoring create configmap scylla-manager-dashboards --from-file=scylla-monitoring-scylla-monitoring-3.6.0/grafana/build/manager_2.2
    kubectl -n scylla-monitoring patch configmap scylla-manager-dashboards  -p '{"metadata":{"labels":{"grafana_dashboard": "1"}}}'
    ```

1. Install Scylla Manager
    ```
    kubectl apply -f manager.yaml
    
    kubectl -n scylla-manager rollout status --timeout=5m statefulset.apps/scylla-manager-cluster-manager-dc-manager-rack
    kubectl -n scylla-manager rollout status --timeout=5m deployment.apps/scylla-manager-controller
    ```

1. Install Scylla and Scylla Manager ServiceMonitors
    ```
    kubectl apply -f namespace.yaml
    kubectl apply -f monitoring/scylla-service-monitor.yaml
    kubectl apply -f monitoring/scylla-manager-service-monitor.yaml
    ```

1. Setup access to Grafana 
    ```
    kubectl -n scylla-monitoring port-forward deployment.apps/monitoring-grafana 3000
    ```

1. Deploy Scylla cluster
    ```
    kubectl apply -f cluster.yaml
    kubectl -n scylla rollout status statefulset.apps/scylla-cluster-us-west1-us-west1-c
    ```

1. Save IO benchmark results
    ```
    kubectl -n scylla exec -ti scylla-cluster-us-west1-us-west1-b-0 -c scylla -- cat /etc/scylla.d/io.conf > io.conf
    kubectl -n scylla exec -ti scylla-cluster-us-west1-us-west1-b-0 -c scylla -- cat /etc/scylla.d/io_properties.yaml > io_properties.yaml
   
    kubectl -n scylla create configmap ioproperties --from-file io_properties.yaml
    kubectl -n scylla create configmap ioconf --from-file io.conf
    ```

1. Remove Scylla cluster
    ```
    kubectl -n scylla delete ScyllaCluster scylla-cluster
    kubectl -n scylla delete pvc --all
    ```

1. Deploy IO tuned Scylla cluster
   ```
    kubectl apply -f cluster_tuned.yaml
    kubectl -n scylla rollout status statefulset.apps/scylla-cluster-us-west1-us-west1-c
    ```
   
1. Run cassandra-stress CQL traffic
    ```
    kubectl apply -f cassandra-stress.yaml
    ```

1. Remove Scylla cluster
    ```
    kubectl -n scylla delete ScyllaCluster scylla-cluster
    kubectl -n scylla delete pvc --all
    ```
1. Deploy Alternator cluster
   ```
   kubectl apply -f alternator.yaml
   kubectl -n scylla rollout status statefulset.apps/scylla-cluster-us-west1-us-west1-b
   ```

1. Run TickTackToe game
   ```
      kubectl apply -f ticktacktoe.yaml
      kubectl -n ticktacktoe get svc
   ```
1. Check for ExternalIP address of a game, it may take some time before it is assigned
1. Access game using ExternalIP address of a service
