#!/bin/bash

# Application startup script for the Docker container
# This script ensures proper setup before starting the Streamlit app

set -e

echo "🚀 Starting Feature Store Application Setup..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to wait for ScyllaDB to be ready
wait_for_scylla() {
    local max_attempts=60
    local attempt=1
    
    log_info "Waiting for ScyllaDB cluster to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        # Try to connect to node1
        if cqlsh node1 -e "SELECT now() FROM system.local;" >/dev/null 2>&1; then
            log_success "ScyllaDB cluster is ready!"
            return 0
        fi
        
        log_info "Attempt $attempt/$max_attempts - ScyllaDB not ready yet, waiting 5 seconds..."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    log_error "ScyllaDB failed to start after $max_attempts attempts"
    return 1
}

# Function to check if feast keyspace exists
check_feast_keyspace() {
    # Use a robust check to avoid false positives from DESCRIBE output formatting
    if cqlsh node1 -e "DESCRIBE KEYSPACES;" 2>/dev/null | tr 'A-Z' 'a-z' | tr -s ' ' | grep -qw feast; then
        return 0
    else
        return 1
    fi
}

# Function to create feast keyspace
create_feast_keyspace() {
    log_info "Creating feast keyspace..."
    # Try NetworkTopologyStrategy with default DC name first; fall back to SimpleStrategy for local demo
    cqlsh node1 -e "CREATE KEYSPACE IF NOT EXISTS feast WITH replication = {'class': 'NetworkTopologyStrategy', 'datacenter1': 3};" >/dev/null 2>&1 || {
        log_info "Falling back to SimpleStrategy for keyspace creation"
        cqlsh node1 -e "CREATE KEYSPACE IF NOT EXISTS feast WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 3};"
    }
    # Give some time for schema agreement and propagation
    sleep 10
    # Verify keyspace exists
    if ! cqlsh node1 -e "SELECT keyspace_name FROM system_schema.keyspaces WHERE keyspace_name='feast';" 2>/dev/null | grep -qw feast; then
        log_error "Failed to create 'feast' keyspace"
        exit 1
    fi
    log_success "Feast keyspace created!"
}

# Wait for keyspace to be visible on all nodes
wait_for_keyspace_propagation() {
    local nodes=(node1 node2 node3)
    local max_attempts=60
    local attempt=1

    log_info "Waiting for 'feast' keyspace to propagate to all nodes..."

    while [ $attempt -le $max_attempts ]; do
        local all_ok=1
        for n in "${nodes[@]}"; do
            if ! cqlsh "$n" -e "DESCRIBE KEYSPACE feast;" >/dev/null 2>&1; then
                all_ok=0
                break
            fi
        done

        if [ $all_ok -eq 1 ]; then
            log_success "'feast' keyspace is visible on all nodes"
            return 0
        fi

        log_info "Attempt $attempt/$max_attempts - Keyspace not visible everywhere yet, waiting 5 seconds..."
        sleep 5
        attempt=$((attempt + 1))
    done

    log_error "Keyspace 'feast' did not propagate to all nodes in time"
    return 1
}

# Function to setup feast features
setup_feast_features() {
    log_info "Setting up Feast feature store..."
    
    cd /app/feature_repo
    
    # Apply feast configuration
    log_info "Applying Feast configuration..."
    feast apply
    
    # Materialize features
    log_info "Materializing features to online store..."
    CURRENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%S")
    feast materialize-incremental $CURRENT_TIME
    
    cd /app
    log_success "Feast setup completed!"
}

# Function to train the model if not already trained
train_model_if_needed() {
    log_info "Checking if model needs training..."
    
    # Check if model files exist
    if [ ! -f "/app/model.bin" ] || [ ! -f "/app/encoder.bin" ]; then
        log_info "Model files not found. Training model..."
        python /app/run.py
        log_success "Model training completed!"
    else
        log_info "Model files already exist. Skipping training."
    fi
}

# Main setup function
main() {
    # Wait for ScyllaDB to be ready
    wait_for_scylla
    
    # Create feast keyspace if it doesn't exist
    if ! check_feast_keyspace; then
        create_feast_keyspace
    else
        log_info "Feast keyspace already exists"
    fi

    # Ensure schema agreement/visibility on all nodes before proceeding
    wait_for_keyspace_propagation
    
    # Setup feast features
    setup_feast_features
    
    # Train model if needed
    train_model_if_needed
    
    log_success "🎉 All setup completed! Starting Streamlit application..."

    # Start the Streamlit app
    exec streamlit run /app/app.py --server.address 0.0.0.0 --server.port 8501
}

# Handle script interruption
trap 'log_error "Setup interrupted"; exit 1' INT TERM

# Run main function
main "$@"
