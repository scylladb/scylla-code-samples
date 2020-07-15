# Kubernetes Operator Demo

## Prerequisites

Your shell needs the following properties set for the scripts to work:

* `GCP_USER=$(gcloud config list account --format "value(core.account)")`
* `GCP_PROJECT=$(gcloud config list project --format "value(core.project)")`
* `GCP_ZONE="us-west1-b"`

You can of course set these however you like but this is the tried and known working set of properties.

## TLDR

1. `./gke.sh -u $GCP_USER -p "$GCP_PROJECT" -z "$GCP_ZONE" -c "kubernetes-alternator-demo"`
2. `./webinar.sh`

This will launch a series a commands some of which are interactive requiring key press to continue.

## Scripts

Generally the scripts all execute one or several commands with an informative interactive message in between.
The scripts usually implements a change to the system such a deployment but also other statements such as `kubectl describe` or `kubectl logs` to highlight the changes that the script introduces. 

### `bootstrap.sh`

The `bootstrap.sh` script simply brings up the whole setup with a running Scylla cluster and monitoring in place.
This script isn't used in the demo but exist for your convenience.

### `cluster.sh`

The `cluster.sh` script installs the Scylla cluster. It assumes the operator is already deployed.

### `edit-cluster.sh`

The `edit-cluster.sh` simply executes a `kubectl edit` on the scylla resource to allow for editing the cluster.

### `gke.sh`

The `gke.sh` sets up a Kubernetes cluster in Google Cloud.

### `grafana-web-ui.sh`

The `grafana-web-ui.sh` script sets up port forwarding to grafana from you local computer. 
It will also use `xdg-open` to launch a browser to view the monitoring web interface.
It assumes that monitoring is properly deployed.

## `init.sh`

The `init.sh` is sourced by the other scripts and not one to use manually.

### `monitoring.sh`

The `monitoring.sh` script installs scylla monitoring with Grafana, Prometheus and the Scylla dashboards.

### `operator.sh`

The `operator.sh` script deploys the Scylla Operator.

### `tictactoe.sh`

The `tictactoe.sh` script deploys the The [Tic Tac Toe](https://github.com/amazon-archives/dynamodb-tictactoe-example-app) app.
It also deploys a service and an ingress to allow for external users to play the game.

### `webinar.sh`

The `webinar.sh` script is a script that simply calls other scripts in the desired order the demo.
This is probably the script you may want to change in order to customize your own demo.