### Walkthrough

1. Spin up a GKE cluster
    ```
    # Set GCP user and project env variables based on current gcloud configuration
   
    export GCP_USER=$(gcloud config list account --format "value(core.account)")        
    export GCP_PROJECT=$(gcloud config list project --format "value(core.project)")
  
    # Start script creating GKE cluster suitable for this demo.
    # This script creates K8s cluster in 2 availability zones (us-west-1b, us-west-1c)
    # each consisting of 3 nodes (n1-standard-4) dedicated to Scylla,
    # and single node (n1-standard-8) dedicated for utilities like Grafana, Prometheus, Scylla Operator etc.
    # and client applications.
   
    ./gke.sh --gcp-user "$GCP_USER" -p "$GCP_PROJECT" -c "university-live-demo"
    ```
1. Install cert-manager - Scylla Operator dependency
    ```
    # Install Scylla Operator dependency - Cert Manager.
    kubectl apply -f cert-manager.yaml
    
    # Wait until installation is complete and ready to go.
   
    kubectl wait --for condition=established crd/certificates.cert-manager.io crd/issuers.cert-manager.io
    kubectl -n cert-manager rollout status --timeout=5m deployment.apps/cert-manager-cainjector
    kubectl -n cert-manager rollout status --timeout=5m deployment.apps/cert-manager-webhook
    ```

1. Install Scylla Operator
    ```
    # Install Scylla Operator
   
    kubectl apply -f operator.yaml
   
    # Wait until installation is complete and ready to go.
   
    kubectl wait --for condition=established crd/scyllaclusters.scylla.scylladb.com
    kubectl wait --for condition=established crd/nodeconfigs.scylla.scylladb.com
    kubectl wait --for condition=established crd/scyllaoperatorconfigs.scylla.scylladb.com
    kubectl -n scylla-operator rollout status deployment.apps/scylla-operator
    kubectl -n scylla-operator rollout status deployment.apps/webhook-server
    ```

1. Install Prometheus monitoring
    ```
    # Add Prometheus Community Helm repository to local registry.
   
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   
    # Update local registry.
   
    helm repo update
    
    # Install monitoring stack (Grafana, Prometheus)
   
    helm install monitoring prometheus-community/kube-prometheus-stack --values monitoring/values.yaml --values monitoring.yaml --create-namespace --namespace scylla-monitoring
    ```

1. Install Scylla Monitoring dashboards
    ```
    # Download and extract 3.6.0 Scylla Monitoring dashboards
   
    wget https://github.com/scylladb/scylla-monitoring/archive/scylla-monitoring-3.6.0.tar.gz
    tar -xvf scylla-monitoring-3.6.0.tar.gz
    
    # Import Scylla dashboards to Grafana
   
    kubectl -n scylla-monitoring create configmap scylla-dashboards --from-file=scylla-monitoring-scylla-monitoring-3.6.0/grafana/build/ver_4.3
    kubectl -n scylla-monitoring patch configmap scylla-dashboards  -p '{"metadata":{"labels":{"grafana_dashboard": "1"}}}'
    
    # Import Scylla Manager dashboard to Grafana
   
    kubectl -n scylla-monitoring create configmap scylla-manager-dashboards --from-file=scylla-monitoring-scylla-monitoring-3.6.0/grafana/build/manager_2.2
    kubectl -n scylla-monitoring patch configmap scylla-manager-dashboards  -p '{"metadata":{"labels":{"grafana_dashboard": "1"}}}'
    ```

1. Install Scylla Manager
    ```
    # Install Scylla Manager - it can be used for repairs and backups.
   
    kubectl apply -f manager.yaml
    
    # Wait until installation is complete and ready to go.
   
    kubectl -n scylla-manager rollout status statefulset.apps/scylla-manager-cluster-manager-dc-manager-rack
    kubectl -n scylla-manager rollout status deployment.apps/scylla-manager-controller
    ```

1. Install Scylla and Scylla Manager ServiceMonitors
    ```
    # Create `scylla` namespace - in this namespace later we will create Scylla cluster.
   
    kubectl apply -f namespace.yaml
   
    # Install Scylla and Scylla Manager Service Monitors - these resources helps Prometheus discover Scylla and Scylla Manager.
    kubectl apply -f monitoring/scylla-service-monitor.yaml
    kubectl apply -f monitoring/scylla-manager-service-monitor.yaml
    ```

1. Setup access to Grafana 
    ```
    # Create tunnel to port 3000 inside Grafana Pod - this command will block until tunnel connection is established.
    kubectl -n scylla-monitoring port-forward deployment.apps/monitoring-grafana 3000
   
   # To access Grafana simply go to http://127.0.0.1:3000/
    ```

1. First deploy small cluster to benchmark the disks. We will use the results later to speedup bootstrap. 
    ```
    # Deploy our example Scylla cluster. 
    kubectl apply -f cluster.yaml
   
    # Wait until Scylla boots up and reports readiness to serve traffic.
    kubectl -n scylla rollout status statefulset.apps/scylla-cluster-us-west1-us-west1-b
    ```

1. Save IO benchmark results by saving result file content from Scylla Pod to ConfigMap.
    ```
    # Save benchmark result to `io_properties.yaml` file
    kubectl -n scylla exec -ti scylla-cluster-us-west1-us-west1-b-0 -c scylla -- cat /etc/scylla.d/io_properties.yaml > io_properties.yaml
    
    # Create a ConfigMap from `io_properties.yaml` file
    kubectl -n scylla create configmap ioproperties --from-file io_properties.yaml
    ```

1. Remove previous Scylla cluster and clear PVC to release and erase the disk.
    ```
    kubectl -n scylla delete ScyllaCluster scylla-cluster
    kubectl -n scylla delete pvc --all
    ```

1. Deploy IO tuned Scylla cluster. Take a look at the definition in file. IO Setup was disabled via additional ScyllaArgs,
   and previously created ConfigMap is attached as Volume. 
   ```
    # Deploy cluster and wait until both racks are ready.
    # This time Scylla is using precomputed disk benchmark so each Pod should be ready faster.
   
    kubectl apply -f cluster_tuned.yaml
    kubectl -n scylla rollout status statefulset.apps/scylla-cluster-us-west1-us-west1-b
    kubectl -n scylla rollout status statefulset.apps/scylla-cluster-us-west1-us-west1-c
    ```
   
1. Run cassandra-stress CQL traffic
    ```
    # Create Job and execute cassandra-stress to generate CQL traffic
    
    kubectl apply -f cassandra-stress.yaml
    ```
1. Go to Grafana (http://127.0.0.1:3000) to see metrics from the workload.
   
1. Remove Scylla cluster, clear the disks and remove cassnadra-stress Job.
    ```
    kubectl -n scylla delete ScyllaCluster scylla-cluster
    kubectl -n scylla delete pvc --all

    kubectl delete -f cassandra-stress.yaml

    ```
1. Deploy Alternator cluster
   ```
   kubectl apply -f alternator.yaml
   kubectl -n scylla rollout status statefulset.apps/scylla-cluster-us-west1-us-west1-b
   kubectl -n scylla rollout status statefulset.apps/scylla-cluster-us-west1-us-west1-c

   ```

1. Run TicTacToe game
   ```
      kubectl apply -f tictactoe.yaml
      kubectl -n tictactoe get svc
   ```
1. Check for ExternalIP address of a game, it may take some time before it is assigned
1. Access game using ExternalIP address of a service, and enjoy the game!
