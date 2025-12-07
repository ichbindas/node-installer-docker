#!/bin/bash
# Docker Compose Execution based on docker-compose.yml

# =============================================================================
# CONFIGURATION
# =============================================================================
BASE_DIR=${DUSK_BASE_DIR:-/opt/dusk}
NODES_DIR="$BASE_DIR/nodes"
DOCKER_COMPOSE_FILE="$BASE_DIR/docker-compose.yml"

# =============================================================================
# NODE MANAGEMENT
# =============================================================================
create_node_directories() {
    local node_num=$1
    local node_dir="$NODES_DIR/node-$node_num"
    # Create necessary directories
    mkdir -p "$node_dir/data" "$node_dir/logs"
    # The config directory will be created by the container
}

# =============================================================================
# DOCKER COMPOSE MANAGEMENT
# =============================================================================
validate_docker_environment() {
    log_info "🔍 Validating Docker environment..."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "❌ Docker is not installed"
        return 1
    fi

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "❌ Docker daemon is not running"
        return 1
    fi

    # Check if Docker Compose is available
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "❌ Docker Compose is not installed"
        return 1
    fi

    # Check if docker-compose.yml exists
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        log_error "❌ Docker Compose file not found at $DOCKER_COMPOSE_FILE"
        log_error "Please generate the docker-compose.yml file first using generate-docker-compose.py"
        return 1
    fi

    log_info "✅ Docker environment validation passed"
    return 0
}

execute_docker_compose() {
    log_section_start "Docker Compose Execution"

    # Change to the base directory
    cd "$BASE_DIR" || {
        log_error "❌ Failed to change to directory: $BASE_DIR"
        log_section_end "Docker Compose Execution" "ERROR"
        return 1
    }

    # Determine the correct docker-compose command
    local compose_cmd
    if command -v docker-compose &> /dev/null; then
        compose_cmd="docker-compose"
    elif docker compose version &> /dev/null; then
        compose_cmd="docker compose"
    else
        log_error "❌ Neither docker-compose nor docker compose is available"
        log_section_end "Docker Compose Execution" "ERROR"
        return 1
    fi

    # Pull the latest images
    log_info "🔄 Pulling latest Docker images..."
    if ! $compose_cmd pull; then
        log_error "❌ Failed to pull Docker images"
        log_section_end "Docker Compose Execution" "ERROR"
        return 1
    fi

    # Build and start the containers
    log_info "🚀 Starting Docker containers..."
    if ! $compose_cmd up -d --build; then
        log_error "❌ Failed to start Docker containers"
        log_section_end "Docker Compose Execution" "ERROR"
        return 1
    fi

    # Verify containers are running
    log_info "🔍 Verifying container status..."
    local container_count=$($compose_cmd ps -q | wc -l)
    if [[ "$container_count" -lt "$ADD_NODES" ]]; then
        log_error "❌ Not all containers are running (Expected: $ADD_NODES, Running: $container_count)"
        log_section_end "Docker Compose Execution" "ERROR"
        return 1
    fi

    log_section_end "Docker Compose Execution" "SUCCESS"
    return 0
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================
main_docker_setup() {
    log_section_start "Docker Compose Setup"

    # Create base directories if they don't exist
    mkdir -p "$BASE_DIR" "$NODES_DIR"

    # Get existing node count
    local existing_nodes=$(find "$NODES_DIR" -maxdepth 1 -type d -name "node-*" | wc -l)

    # Add new nodes
    for ((i=1; i<=$ADD_NODES; i++)); do
        local node_num=$((existing_nodes + i))

        log_info "Creating host directories for node $node_num"

        # Create node directories
        create_node_directories "$node_num"

        log_section_end "Finished creating host directories for node $node_num"
    done

    # Validate Docker environment
    if ! validate_docker_environment; then
        log_error "❌ Docker environment validation failed"
        log_section_end "Docker Compose Setup" "ERROR"
        return 1
    fi

    # Execute Docker Compose
    if ! execute_docker_compose; then
        log_error "❌ Docker Compose execution failed"
        log_section_end "Docker Compose Setup" "ERROR"
        return 1
    fi

    log_section_end "Docker Compose Setup" "SUCCESS"
    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_docker_setup
fi