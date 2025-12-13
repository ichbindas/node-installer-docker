#!/bin/bash
# Docker Compose Execution based on docker-compose.yml

# =============================================================================
# CONFIGURATION
# =============================================================================
# Define color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Example usage
#echo -e "${RED}This is a red message${NC}"
#echo -e "${GREEN}This is a green message${NC}"
#echo -e "${YELLOW}This is a yellow message${NC}"
#echo -e "${BLUE}This is a blue message${NC}"

# Define Paths
BASE_DIR=${DUSK_BASE_DIR:-/opt/dusk}
DOCKER_COMPOSE_FILE="$BASE_DIR/docker-compose.yml"
DOCKER_BUILDKIT=${DOCKER_BUILDKIT:0}
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-dusk-}"

# =============================================================================
# DOCKER COMPOSE MANAGEMENT
# =============================================================================
validate_docker_environment() {
    echo "🔍 Validating Docker environment..."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker is not installed"
        return 1
    fi

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        echo "❌ Docker daemon is not running"
        return 1
    fi

    # Check if Docker Compose is available
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo "❌ Docker Compose is not installed"
        return 1
    fi

    # Check if docker-compose.yml exists
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        echo "❌ Docker Compose file not found at $DOCKER_COMPOSE_FILE"
        echo "Please generate the docker-compose.yml file first using ./scripts/generate-docker-compose.py"
        return 1
    fi

    echo "✅ Docker environment validation passed"
    return 0
}

execute_docker_compose() {
    echo "Docker Compose Execution"

    # Change to the base directory
    cd "$BASE_DIR" || {
        echo "❌ Failed to change to directory: $BASE_DIR"
        echo "Docker Compose Execution" "ERROR"
        return 1
    }

    # Determine the correct docker-compose command
    local compose_cmd
    if command -v docker-compose &> /dev/null; then
        compose_cmd="docker-compose"
    elif docker compose version &> /dev/null; then
        compose_cmd="docker compose"
    else
        echo "❌ Neither docker-compose nor docker compose is available"
        echo "Docker Compose Execution" "ERROR"
        return 1
    fi

    echo "🔨 Building images (verbose)..."
    if ! $compose_cmd -p "$COMPOSE_PROJECT_NAME" -f "$DOCKER_COMPOSE_FILE" build --progress=plain; then
        echo "❌ Image build failed"
        return 1
    fi

    echo "🚀 Starting containers..."
    if ! $compose_cmd -p "$COMPOSE_PROJECT_NAME" -f "$DOCKER_COMPOSE_FILE" up -d; then

        echo "❌ Failed to start containers"
        return 1
    fi

    # Verify all services are running
    echo "🔍 Verifying service status..."

    local total_services
    local running_services

    total_services=$($compose_cmd ps --services | wc -l)
    running_services=$($compose_cmd ps --status running --services | wc -l)

    if [[ "$running_services" -ne "$total_services" ]]; then
        echo "❌ Not all services are running"
        echo "Expected: $total_services, Running: $running_services"
        echo ""
        echo "Service status:"
        $compose_cmd ps
        return 1
    fi

    echo "✅ All $running_services services are running"
    echo "Docker Compose Execution" "SUCCESS"
    return 0
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================
main_docker_setup() {
    echo "Docker Compose Setup"

    # Validate Docker environment
    if ! validate_docker_environment; then
        echo "❌ Docker environment validation failed"
        echo "Docker Compose Setup" "ERROR"
        return 1
    fi

    # Execute Docker Compose
    if ! execute_docker_compose; then
        echo "❌ Docker Compose execution failed"
        echo "Docker Compose Setup" "ERROR"
        return 1
    fi

    echo "Docker Compose Setup" "SUCCESS"
    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_docker_setup
fi