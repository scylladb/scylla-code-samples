# ScyllaDB Feature Store - Quick Start Guide

This guide shows you how to run the complete ScyllaDB Feature Store application with a single command.

## Prerequisites

- Docker and Docker Compose installed
- At least 8GB of available RAM
- Ports 8501, 9042-9044, 9180-9182 available

## Quick Start

### Option 1: One-Command Setup (Recommended)

Run the complete setup with a single command:

```bash
./setup_and_run.sh
```

This script will:
1. ✅ Start a 3-node ScyllaDB cluster using Docker Compose
2. ✅ Wait for all nodes to be ready
3. ✅ Create the required `feast` keyspace
4. ✅ Set up Feast feature store configuration
5. ✅ Materialize features to the online store (ScyllaDB)
6. ✅ Train the credit scoring model
7. ✅ Start the Streamlit application

### Option 2: Manual Docker Compose

If you prefer to run Docker Compose manually:

```bash
docker-compose up -d
```

The application container will automatically handle all setup steps.

## Access the Application

Once setup is complete, you can access:

- **Feature Store App**: http://localhost:8501
- **ScyllaDB Nodes**:
  - Node 1: localhost:9042
  - Node 2: localhost:9043
  - Node 3: localhost:9044

## Monitoring

View application logs:
```bash
docker-compose logs -f feature-store-app
```

View ScyllaDB logs:
```bash
docker-compose logs -f node1 node2 node3
```

## Stopping the Application

```bash
docker-compose down
```

## Troubleshooting

### If the application fails to start:

1. Check if all ports are available:
   ```bash
   netstat -tulpn | grep -E ':(8501|9042|9043|9044|9180|9181|9182)\s'
   ```

2. Check container logs:
   ```bash
   docker-compose logs feature-store-app
   ```

3. Restart the setup:
   ```bash
   docker-compose down
   ./setup_and_run.sh
   ```

### If model training fails:

The application will automatically retry model training. Check that:
- All ScyllaDB nodes are healthy
- The feast keyspace was created successfully
- Feature materialization completed

## What's Included

- **3-Node ScyllaDB Cluster**: High-availability setup with replication factor 3
- **Feast Feature Store**: Open-source feature store framework
- **Credit Scoring Model**: Pre-trained ML model for loan approval predictions
- **Streamlit Web App**: Interactive UI for testing loan applications
- **Sample Data**: Zipcode features and credit history data

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   ScyllaDB      │    │   ScyllaDB      │    │   ScyllaDB      │
│     Node 1      │    │     Node 2      │    │     Node 3      │
│   (Port 9042)   │    │   (Port 9043)   │    │   (Port 9044)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  Feast Feature  │
                    │     Store       │
                    │  (Online Store) │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Streamlit     │
                    │      App        │
                    │  (Port 8501)    │
                    └─────────────────┘
```

The application demonstrates real-time feature serving for machine learning using ScyllaDB as the online feature store backend.
