#!/bin/bash

# ScyllaDB Feature Store Setup and Run Script
# This script sets up the entire feature store application with proper dependencies

set -e  # Exit on any error

echo "🚀 Starting ScyllaDB Feature Store Setup..."

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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to wait for ScyllaDB to be ready
wait_for_scylla() {
    local node=$1
    local max_attempts=30
    local attempt=1
    
    log_info "Waiting for $node to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec $node nodetool status >/dev/null 2>&1; then
            log_success "$node is ready!"
            return 0
        fi
        
        log_info "Attempt $attempt/$max_attempts - $node not ready yet, waiting 10 seconds..."
        sleep 10
        attempt=$((attempt + 1))
    done
    
    log_error "$node failed to start after $max_attempts attempts"
    return 1
}

# Function to execute CQL commands
execute_cql() {
    local node=$1
    local cql_command="$2"
    
    log_info "Executing CQL: $cql_command"
    docker exec -i $node cqlsh -e "$cql_command"
}

# Function to check if feast keyspace exists
check_feast_keyspace() {
    local node=$1
    if docker exec -i $node cqlsh -e "DESCRIBE KEYSPACE feast;" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to setup feast features
setup_feast_features() {
    log_info "Setting up Feast feature store..."
    
    # Change to feature_repo directory
    cd feature_repo
    
    # Apply feast configuration
    log_info "Applying Feast configuration..."
    feast apply
    
    # Materialize features
    log_info "Materializing features to online store..."
    CURRENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%S")
    feast materialize-incremental $CURRENT_TIME
    
    cd ..
}

# Function to train the model
train_model() {
    log_info "Training the credit scoring model..."
    python run.py
    log_success "Model training completed!"
}

# Main execution starts here
main() {
    log_info "Starting Docker Compose services..."
    
    # Start the services
    docker-compose up -d
    
    # Wait for all ScyllaDB nodes to be ready
    wait_for_scylla "scylla-node1"
    wait_for_scylla "scylla-node2" 
    wait_for_scylla "scylla-node3"
    
    log_success "All ScyllaDB nodes are ready!"
    
    # Create the feast keyspace if it doesn't exist
    if ! check_feast_keyspace "scylla-node1"; then
        log_info "Creating feast keyspace..."
        execute_cql "scylla-node1" "CREATE KEYSPACE IF NOT EXISTS feast WITH replication = {'class': 'NetworkTopologyStrategy', 'replication_factor': '3'};"
        log_success "Feast keyspace created!"
    else
        log_info "Feast keyspace already exists"
    fi
    
    # Wait a bit for keyspace to propagate
    sleep 5
    
    # Setup feast features and train model inside the feature-store-app container
    log_info "Setting up Feast and training model inside the application container..."
    
    # Execute setup commands inside the feature-store-app container
    docker exec feature-store-app bash -c "
        set -e
        echo 'Setting up Feast feature store...'
        cd /app/feature_repo
        feast apply
        echo 'Materializing features...'
        CURRENT_TIME=\$(date -u +'%Y-%m-%dT%H:%M:%S')
        feast materialize-incremental \$CURRENT_TIME
        echo 'Training model...'
        cd /app
        python run.py
        echo 'Setup completed successfully!'
    "
    
    log_success "Feature store setup and model training completed!"
    
    # Check if the app is running
    if docker ps | grep -q "feature-store-app"; then
        log_success "🎉 Feature Store Application is running!"
        log_info "Access the application at: http://localhost:8501"
        log_info "ScyllaDB nodes are available at:"
        log_info "  - Node 1: localhost:9042"
        log_info "  - Node 2: localhost:9043" 
        log_info "  - Node 3: localhost:9044"
        echo ""
        log_info "To view logs: docker-compose logs -f feature-store-app"
        log_info "To stop: docker-compose down"
    else
        log_error "Feature store application failed to start"
        docker-compose logs feature-store-app
        exit 1
    fi
}

# Handle script interruption
trap 'log_warning "Script interrupted. Cleaning up..."; docker-compose down; exit 1' INT TERM

# Run main function
main "$@"
