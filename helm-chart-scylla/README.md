# ScyllaDB Helm Chart on GKE

 ## What is Helm Charts? Why use a Helm Chart? 
  
Helm uses a packaging format called charts. A chart is a collection of files that describe a related set of Kubernetes resources. A single chart might be used to deploy something simple, like a memcached pod, or something complex, like a full web app stack with HTTP servers, databases, caches, and so on. 

Helm Charts deploys all the kubernetes entities in a ordered fashion wrapping them together in a RELEASE. In addition to that you also get versioning control allowing you to upgrade your release and rolling back changes.

A good introduction to Helm Charts by Amy Chen can be found [here](https://youtu.be/vQX5nokoqrQ)

## Running on GKE:
  
  [Install Google Cloud SKD](https://cloud.google.com/sdk/)

  * Authenticate to your GCP
    
    `gcloud init`
  
  * Install kubectl
    
    `gcloud components install kubectl`

  * Create your cluster on GKE. [How do I find my project id on GCP?](https://cloud.google.com/resource-manager/docs/creating-managing-projects?visit_id=1-636622601155195003-3404293793&rd=1#identifying_projects)
    
    `https://console.cloud.google.com/kubernetes/add?<your-project-id>`

    ```clusterName: helm-test
    yourZone: us-central1-a
    clusterVersion: 1.9.7-gke.0
    machineType: 1vCPU 3.75GB
    nodeImage: Container-Optimized OS (cos)
    size: 3```
    
  * Get credentials for your GKE cluster
    
    `gcloud container clusters get-credentials <clusterName> --zone <yourZone> --project <your-project-id>`

  * Check your setup
    
    `kubectl config current-context`
    
     You should see something like: `gke_<your-project-id>_<yourZone>_<clusterName>` 
    
    
  [Install Helm](https://docs.helm.sh/using_helm/#installing-helm)
  
  * Clone our repository
    
    `git clone https://github.com/scylladb/scylla-code-samples.git`
    
    `cd scylla-code-samples`
  
  * Get your password
    
    `gcloud container clusters describe <clusterName> --zone <yourZone> | grep pass`
    
    take note of your password here to use on next steps
    
  * Setup RBAC
    
    `kubectl create serviceaccount --namespace kube-system tiller`
    
    `kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'`
    
    `kubectl --username=admin --password=<password> create -f scylladb-gke/tiller-clusterrolebinding.yaml`
    
    `kubectl --username=admin --password=<password> create -f scylladb-gke/cluster-admin.yaml`
    
  * Install the helm chart 
    
    `helm install scylladb-gke` 
    
    This is going to install a new helm release with a random name. We will use the release name on the next steps.
    
  * Get the name of your helm release 
    
    `helm list` 
    
  * Check the status 
    
    `helm status <releaseName>` 
    
  * Check your scylla cluster 
    
    `kubectl exec -ti <some-pod-name> -- nodetool status # Check your cluster`
    
    `kubectl logs <some-pod-name> # Check the logs for some pod`
    
  * Grow your cluster by upgrading your Release - adding 2 more nodes. This will update the REVISION number on your release 
    
    `helm upgrade --set replicaCount=5, <releaseName> scylladb-gke/` 
    
    `helm history <releaseName>`
    
    `kubectl exec -ti <some-pod-name> -- nodetool status`

  * Shrink your cluster by upgrading your Release - removing one node
    
    `helm upgrade --set replicaCount=4, <releaseName> scylladb-gke/` 
    
    `helm history <releaseName>`
    
    `kubectl exec -ti <some-pod-name> -- nodetool status`
    
  * Shrink your cluster by rolling back to REVISION 1 - removing another node
    
    `helm rollback alliterating-lion 1` 
    
    `helm history <releaseName>`
    
    `kubectl exec -ti <some-pod-name> -- nodetool status`
    
  * Delete your helm release
    
    `helm delete <releaseName>`
