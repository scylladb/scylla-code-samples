#!/bin/bash

. ./init.sh

GCP_REGION="us-west1"
GCP_ZONE="us-west1-b"

./monitoring.sh --non-interactive
./operator.sh --non-interactive

sleep 10

./cluster.sh --non-interactive
./grafana-web-ui.sh --non-interactive