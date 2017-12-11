# Automating Scylla deployments with Kubernetes

This example demonstrates a simple example of deploying a Scylla cluster on Google Compute Engine with the open-source distribution of Kubernetes.

Our goal is to be able to elastically scale our cluster up and down and for the Scylla nodes to automatically join the ring.

## Overview

### `Services` and `StatefulSets`

A typical way to organize replicated containers is through `Services`, which automatically load-balance all instances behind a single IP address.

However, in a stateful application like Scylla with its own cluster management at the application level, treating all instances as interchangable is not suitable.

A `StatefulSet` (previously called a `PetSet`) is similar to a `Service`, but designates persistent names like `scylla-0`, `scylla-1`, ..., `scylla-n` which get dynamically bound to particular `Pods`.

We still use a "headless" `Service` (without a single IP address) for aggregating all the running `Pods`.

### Determining when an instance is ready

Kubernetes queries running instances to determine when they're ready. A simple shell script, `ready-probe.sh`, uses `nodetool` to check the status of the node and reports success once it has joined the Scylla cluster.

We use a `ConfigMap` to describe the `ready-probe.sh` file, and mount the file at `/opt/ready-probe.sh` in the `StatefulSet` description.

### Storage and `PersistentVolumes`

A `StatefulSet` also describes a template for a `PersistentVolumeClaim` for each `Pod`. `PersistentVolumes` are dynamically created based on the number of instances in the `StatefulSet` using the Google Compute Engine storage provisioner.

After a `PersistentVolume` has been created, it can be dynamically bound to different `Pods` as the need arises.

### Seeding the cluster

A "seed" list in Scylla's configuration instructs new nodes on which nodes to contact in order to join the Scylla cluster. While the IP address of particular pods is ephemeral, the static identifiers created by the `StatefulSet` also get mapped to DNS records. We can specify the seed node using these host names. An example is `scylla-0.scylla.default.svc.cluster.local`

## Demo

This example uses Scylla 2.0.0. It assumes that the Kubernetes management tools (`kubectl`, etc) have been installed locally. We use Google Compute Engine with Kubernetes: the cluster initialization script, `cluster/kube-up.sh`, quickly and automatically creates a 4 node Kubernetes cluster.

- First, create the `StorageClass` instructing Kubernetes on the kind of volumes to create (SSD):
  ```bash
  $ kubectl create -f scylla-storageclass.yaml
  ```

- Next, create the `Service` aggegating Scylla `Pods`:
  ```bash
  $ kubectl create -f scylla-service.yaml
  ```
  
- Create the `ConfigMap`, for the readiness-checking file:
  ```bash
  $ kubectl create -f scylla-configmap.yaml
  ```
  
- Finally, we're ready to instantiate our Scylla cluster with three nodes:
  ```bash
  $ kubectl create -f scylla-statefulset.yaml
  ```
  
We can query the resources we've created with commands like `kubectl get statefulsets` or `kubectl describe storageclass scylla`.

To query the state of the `Pods`, execute `kubectl get pods`. Once all `Pods` are ready, we can use `nodetool` to observe the state of the Scylla cluster:

```bash
$ kubectl exec scylla-0 -- nodetool status
```


Finally, we can increase the size of our cluster:

```bash
$ kubectl edit statefulset scylla
```

Increase the number of replicas to 4, then save the file, and exit. The new node should join the ring.

Again, we can use `nodetool status` to observe that the Scylla cluster now consists of 4 nodes.

# References

- [Scalable multi-node Cassandra deployment on Kubernetes Cluster](https://github.com/IBM/Scalable-Cassandra-deployment-on-Kubernetes/blob/master/README.md)
- [Google Cloud Platform Quickstart for Linux](https://cloud.google.com/sdk/docs/quickstart-linux)
- [Running Kubernetes on Google Compute Engine](https://kubernetes.io/docs/getting-started-guides/gce/)
- [Example: Deploying Cassandra with Stateful Sets](https://kubernetes.io/docs/tutorials/stateful-application/cassandra/)
- [Strategies for Running Stateful Workloads in Kubernetes](https://thenewstack.io/strategies-running-stateful-applications-kubernetes-pet-sets/)
