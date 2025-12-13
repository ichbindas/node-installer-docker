#!/bin/bash

# Dusk Node Containers - Main Installer
# Orchestrates the complete installation process

# =============================================================================
# SCRIPT CONFIGURATION
# =============================================================================

# Script information
SCRIPT_NAME="Dusk Docker Containers"
SCRIPT_VERSION="1.0.0"

PHASES=(
    "01-docker-setup"
)

# ConfigurationI 
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$INSTALL_DIR/modules"
CONFIG_DIR="$INSTALL_DIR/../config"

# =============================================================================
# CONFIGURATION LOADING
# =============================================================================
# Load default configuration
DEFAULT_CONFIG=(
  "DUSK_BASE_DIR=/opt/dusk"
  "ADD_NODES=1"
  "FAST_SYNC_ENABLED=false"
  "NETWORK=mainnet"
)

# Apply default configuration
for config in "${DEFAULT_CONFIG[@]}"; do
  key="${config%%=*}"
  value="${config#*=}"
  if [[ -z "${!key}" ]]; then
    export "$key"="$value"
  fi
done

# Load configuration from .env file if available
if [[ -f "$CONFIG_DIR/dusk.env" ]]; then
  echo "📋 Loading configuration from dusk.env"
  source "$CONFIG_DIR/dusk.env"
fi

# Load ICMP configuration if available
if [[ -f "$CONFIG_DIR/icmp-config.env" ]]; then
  source "$CONFIG_DIR/icmp-config.env"
fi

# =============================================================================
# EXPORT ENVIRONMENT VARIABLES
# =============================================================================
export_config_vars() {
  export DUSK_BASE_DIR
  export ADD_NODES
  export FAST_SYNC_ENABLED
}

# Export variables before module execution
export_config_vars

# =============================================================================
# COMMAND LINE ARGUMENTS
# =============================================================================

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --add-nodes)
      if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
        ADD_NODES="$2"
        shift 2
      else
        echo "--add-nodes requires a number"
        show_help
        exit 1
      fi
      ;;
    --fast-sync)
      FAST_SYNC_ENABLED=true
      shift
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Show help information
show_help() {
  cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION
Usage: $0 [OPTIONS]
Options:
--add-nodes N      Add N containers (default: 1)
--fast-sync        Enable fast-sync during installation
--help, -h         Show this help message

Installation Phases:
1. Docker Setup: Configures Docker environment
2. Install Dusk Node: Sets up Dusk node components
3. Fast Sync: Optional state synchronization (when --fast-sync flag is used)

Examples:
sudo $0                    # Normal installation (1 container)
sudo $0 --add-nodes 3       # Install with 3 containers
sudo $0 --fast-sync         # Install with fast-sync
sudo $0 --add-nodes 2       # Add 2 more containers to existing setup
EOF
}

# Check if module exists
check_module_exists() {
  local module_name=$1
  local module_path="$MODULES_DIR/$module_name.sh"

  if [[ -f "$module_path" ]]; then
    echo "Module found: $module_name at $module_path"
    return 0
  else
    echo "Module not found: $module_name"
    echo "Expected location: $module_path"
    echo "Please ensure all required modules are present in $MODULES_DIR"
    return 1
  fi
}

# Execute module with timeout and enhanced logging
execute_module() {
  local module_name=$1
  local module_path="$MODULES_DIR/$module_name.sh"
  local timeout=3600  # 1 hour timeout for modules
  local start_time
  local end_time
  local duration

  echo "Module: $module_name"

  # Check if module exists
  if ! check_module_exists "$module_name"; then
    echo "Module: $module_name" "ERROR"
    return 1
  fi

########## this needs to be updated, fast-sync is currently not implemented
  # Skip fast-sync if not enabled
  #if [ "$FAST_SYNC_ENABLED" != "true" ]; then
  #  echo "ℹ️ Skipping fast-sync (not enabled)"
  #  return 0
  #fi

  start_time=$(date +%s)
  echo "🚀 Starting module: $module_name"

  # Execute module with timeout
  if timeout "$timeout" bash "$module_path"; then
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    echo "Module $module_name completed successfully in $duration seconds"
    echo "Module: $module_name" "SUCCESS"
    return 0
  else
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    echo "Module $module_name failed after $duration seconds"
    echo "Module: $module_name" "ERROR"
    rollback_installation "$module_name"
    echo "Installation rollback complete"
    return 1
  fi
  
}

# current implementation removes all nodes.... 
# Enhanced rollback function
rollback_installation() {
  local failed_module=$1
  echo "🔄 Rolling back installation due to failure in module: $failed_module"
  local base_dir="${DUSK_BASE_DIR:-/opt/dusk}"
  local compose_file="$base_dir/docker-compose.yml"


  # Stop Docker containers
  if [[ -f "$compose_file" ]]; then
    echo "Stopping Docker containers"
    cd "$base_dir" 2>/dev/null || true

    if command -v docker-compose >/dev/null 2>&1; then
      echo "🔧 Running: docker-compose -f $compose_file down"
      docker-compose -f "$compose_file" down 2>/dev/null || true
    elif docker compose version >/dev/null 2>&1; then
      echo "🔧 Running: docker compose down"
      docker compose -f "$compose_file" down  2>/dev/null || true
    fi
  fi

  # Remove created directories if they're empty
  if [[ -d "$DUSK_BASE_DIR" ]]; then
    if [[ -z "$(ls -A "$DUSK_BASE_DIR")" ]]; then
      echo "🗑️ Removing empty installation directory: $DUSK_BASE_DIR"
      rmdir "$DUSK_BASE_DIR" 2>/dev/null || true
    else
      echo "ℹ️ Keeping non-empty installation directory: $DUSK_BASE_DIR"
    fi
  fi

  echo "🔄 Rollback completed. Manual cleanup may be required for non-empty directories."
}


# Enhanced container listing with filtering options
list_containers() {
  echo "📋 Listing existing Dusk node containers..."

  local compose_cmd
  local filter_status=""
  local filter_name="dusk-node"
  local base_dir="${DUSK_BASE_DIR:-/opt/dusk}"
  local compose_file="$base_dir/docker-compose.yml"

  # Determine docker-compose command
  if command -v docker-compose >/dev/null 2>&1; then
    compose_cmd="docker-compose"
    export DOCKER_BUILDKIT=0
    echo "ℹ️ docker-compose v1 detected → using legacy (verbose) build output"
  elif docker compose version >/dev/null 2>&1; then
    compose_cmd="docker compose"
  else
    echo "Docker Compose not found"
    return 1
  fi

  # Show Docker Compose services if available
  if [[ -f "$compose_file" ]]; then
    cd "$base_dir" 2>/dev/null || return 1
    echo ""
    echo "Docker Compose Services:"
    $compose_cmd -f "$compose_file" ps
    echo ""
  else
    echo "ℹ️ No docker-compose.yml found at $compose_file"
  fi

  # Show Docker containers with enhanced formatting
  echo "Docker Containers:"
  docker ps -a \
    --filter "name=$filter_name" \
    --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.CreatedAt}}"

  echo ""
  return 0
}

validate_network() {
  # Validate network
  if [[ "$NETWORK" != "mainnet" && "$NETWORK" != "testnet" ]]; then
    echo "Invalid network specified: $NETWORK. Must be 'mainnet' or 'testnet'"
    return 1
  fi

  return 0
}

########## this also needs to be changed
## node_space_gb is never set (at least not in what you pasted). This will evaluate to 0 or error depending on shell settings, making the check meaningless.

# Check disk space requirements
check_disk_space() {
  local required_space_gb=20  # Base requirement

  # Calculate total required space
  local total_required_gb=$((required_space_gb * ADD_NODES))

  # Get available space in GB
  local available_space_gb=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')

  if [[ "$available_space_gb" -lt "$total_required_gb" ]]; then
    echo "Insufficient disk space"
    echo "Required: ${total_required_gb}GB, Available: ${available_space_gb}GB"
    return 1
  fi

  echo "Disk space check passed (${available_space_gb}GB available)"
  return 0
}

# Check memory requirements
check_memory_requirements() {
  local required_mem_mb=4096  # Base requirement

  # Calculate total required memory
  local total_required_mb=$((required_mem_mb * ADD_NODES))

  # Get available memory in MB
  local available_mem_mb=$(free -m | awk '/Mem:/ {print $7}')

  if [[ "$available_mem_mb" -lt "$total_required_mb" ]]; then
    echo "Insufficient memory"
    echo "Required: ${total_required_mb}MB, Available: ${available_mem_mb}MB"
    return 1
  fi

  echo "Memory check passed (${available_mem_mb}MB available)"
  return 0
}

# Check network connectivity
check_network_connectivity() {
  # Check basic internet connectivity
  if ! ping -c 1 8.8.8.8 &> /dev/null; then
    echo "No internet connectivity detected"
    return 1
  fi

  # Check if we can reach Dusk network nodes
  local test_nodes=("165.232.91.113" "64.226.105.70" "137.184.232.115")
  local reachable=false

  for node in "${test_nodes[@]}"; do
    if ping -c 1 "$node" &> /dev/null; then
      reachable=true
      break
    fi
  done

  if [[ "$reachable" == "false" ]]; then
    echo "Unable to reach Dusk network nodes"
    echo "Check your network configuration and firewall settings"
    return 1
  fi

  echo "Network connectivity check passed"
  return 0
}

# Check Docker installation
check_docker_installation() {
  if ! command -v docker &> /dev/null; then
    echo "Docker is not installed"
    return 1
  fi

  if ! docker info &> /dev/null; then
    echo "Docker daemon is not running"
    return 1
  fi

  echo "Docker installation check passed"
  return 0
}

# Check Docker Compose installation
check_docker_compose_installation() {
  if command -v docker-compose &> /dev/null; then
    echo "Using docker-compose $(docker-compose version)"
    return 0
  elif docker compose version &> /dev/null; then
    echo "Using docker compose $(docker compose version)"
    return 0
  else
    echo "Docker Compose is not installed"
    return 1
  fi
}

# Check installation directory
check_installation_directory() {
  if [[ -d "$DUSK_BASE_DIR" ]]; then
    if [[ ! -w "$DUSK_BASE_DIR" ]]; then
      echo "Installation directory not writable: $DUSK_BASE_DIR"
      return 1
    fi
  else
    if ! mkdir -p "$DUSK_BASE_DIR" &> /dev/null; then
      echo "Unable to create installation directory: $DUSK_BASE_DIR"
      return 1
    fi
  fi

  echo "Installation directory check passed ($DUSK_BASE_DIR)"
  return 0
}

# Check required modules
check_required_modules() {
  local missing_modules=false

  for phase in "${PHASES[@]}"; do
    if ! check_module_exists "$phase"; then
      missing_modules=true
    fi
  done

  if [[ "$missing_modules" == "true" ]]; then
    echo "Some required installation modules are missing"
    return 1
  fi

  echo "Module check passed"
  return 0
}

# Pre-installation validation function
run_pre_installation_checks() {
  local validation_passed=true

  echo "Pre-Installation Checks"

  # Validate network
  if ! validate_network; then
    echo "Network validation failed"
    validation_passed=false
  fi

  # Check disk space
  if ! check_disk_space; then
    echo "Insufficient disk space"
    validation_passed=false
  fi

  # Check memory requirements
  if ! check_memory_requirements; then
    echo "Insufficient memory"
    validation_passed=false
  fi

  # Check network connectivity
  if ! check_network_connectivity; then
    echo "Network connectivity issues detected"
    validation_passed=false
  fi

  # Check Docker installation
  if ! check_docker_installation; then
    echo "Docker not properly installed"
    validation_passed=false
  fi

  # Check Docker Compose installation
  if ! check_docker_compose_installation; then
    echo "Docker Compose not properly installed"
    validation_passed=false
  fi

  # Check if installation directory exists and is writable
  if ! check_installation_directory; then
    echo "Installation directory issues"
    validation_passed=false
  fi

  # Check if required modules exist
  if ! check_required_modules; then
    echo "Required installation modules are missing"
    validation_passed=false
  fi

  # Check if we're running as root (required for some operations)
  if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    validation_passed=false
  fi

  if [[ "$validation_passed" == "false" ]]; then
    echo "Pre-Installation Checks" "FAILED"
    return 1
  fi

  echo "Pre-Installation Checks" "PASSED"
  return 0
}


# =============================================================================
# MAIN INSTALLATION PROCESS
# =============================================================================

# Show installation summary before starting
show_installation_summary() {
  echo "📋 Installation Summary:"
  echo "  - Nodes to install: $ADD_NODES"
  echo "  - Network: $NETWORK"
  echo "  - Base Directory: $DUSK_BASE_DIR"
  echo "  - Fast Sync: $([ "$FAST_SYNC_ENABLED" == "true" ] && echo "Enabled" || echo "Disabled")"
  echo "🔧 Starting installation process..."
}


# Show completion message with enhanced information
show_completion_message() {
  echo ""
  echo "Installation completed successfully!"
  echo ""

  # Show installation summary
  echo "Installation Summary:"
  echo "  - Nodes installed: $ADD_NODES"
  echo "  - Network: $NETWORK"
  echo "  - Base Directory: $DUSK_BASE_DIR"
  echo "  - Fast Sync: $([ "$FAST_SYNC_ENABLED" == "true" ] && echo "Enabled" || echo "Disabled")"
  echo ""

  # Show container status
  echo "📋 Container Status:"
  local compose_cmd
  if command -v docker-compose >/dev/null 2>&1; then
    compose_cmd="docker-compose"
  elif docker compose version >/dev/null 2>&1; then
    compose_cmd="docker compose"
  fi

  if [[ -f "$DUSK_BASE_DIR/docker-compose.yml" && -n "$compose_cmd" ]]; then
    cd "$DUSK_BASE_DIR" 2>/dev/null || true
    echo ""
    $compose_cmd ps
    echo ""
  else
    echo "ℹ️ No docker-compose.yml found at $DUSK_BASE_DIR"
  fi

  # Show node status
  echo "📋 Node Status:"
  if [[ -d "$DUSK_BASE_DIR/nodes" ]]; then
    for node_dir in "$DUSK_BASE_DIR/nodes"/*; do
      if [[ -d "$node_dir" ]]; then
        node_name=$(basename "$node_dir")
        echo "  - $node_name: $(get_node_status "$node_dir")"
      fi
    done
  else
    echo "ℹ️ No nodes directory found at $DUSK_BASE_DIR/nodes"
  fi

  echo ""
  echo "🔧 Useful Commands:"
  echo "  dusk-start              # Start all nodes"
  echo "  dusk-stop               # Stop all nodes"
  echo "  dusk-restart            # Restart all nodes"
  echo "  dusk-status             # Show node status"
  echo "  dusk-logs               # View logs"
  echo ""
  echo "  cd $DUSK_BASE_DIR && $compose_cmd ps    # View container status"
  echo "  cd $DUSK_BASE_DIR && $compose_cmd logs # View all logs"
  echo ""
}


#
#get_node_status() can’t work as written (broken logic)

#Problems:
#	•	It relies on compose_cmd, but compose_cmd is a local variable inside show_completion_message(), so it’s not available in get_node_status().
#	•	It treats container_name=$(basename "$node_dir") (like node-1) as a compose service name. Your compose service is dusk-node-1, so it won’t match.

#If you want this feature, you need to:
#	•	determine compose command inside get_node_status() too (or make it global), and
#	•	map node-1 → dusk-node-1.
#"""


# Get node status
get_node_status() {
  local node_dir="$1"
  local base_dir="${DUSK_BASE_DIR:-/opt/dusk}"
  local compose_file="$base_dir/docker-compose.yml"

  # Determine docker compose command
  local compose_cmd=""
  if command -v docker-compose >/dev/null 2>&1; then
    compose_cmd="docker-compose"
  elif docker compose version >/dev/null 2>&1; then
    compose_cmd="docker compose"
  else
    echo "unknown (no compose)"
    return 0
  fi

  # Need compose file
  if [[ ! -f "$compose_file" ]]; then
    echo "unknown (no compose file)"
    return 0
  fi

  # node_dir basename: node-1, node-2, ...
  local node_name
  node_name="$(basename "$node_dir")"

  # Extract numeric suffix: "1" from "node-1"
  local node_num="${node_name#node-}"
  if [[ -z "$node_num" || ! "$node_num" =~ ^[0-9]+$ ]]; then
    echo "unknown"
    return 0
  fi

  # Compose service name: dusk-node-1, dusk-node-2, ...
  local service="dusk-node-$node_num"

  # Get container id for that service
  local cid
  cid=$($compose_cmd -f "$compose_file" ps -q "$service" 2>/dev/null)

  if [[ -z "$cid" ]]; then
    echo "not created"
    return 0
  fi

  # Get state via docker inspect (more reliable than parsing ps output)
  local status
  status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null)"
  if [[ -z "$status" ]]; then
    echo "unknown"
  else
    echo "$status"   # running / exited / restarting / etc.
  fi
}

# Main installation function
main_installation() {
  echo "Dusk Docker Container"

  # Display installation summary
  show_installation_summary

  # Pre-installation validation
  echo "🔍 Running pre-installation validation..."
  if ! run_pre_installation_checks ; then
    echo "Pre-installation validation failed"
    echo "Dusk Docker Container" "ERROR"
    exit 1
  fi

  # Execute each phase
  for phase in "${PHASES[@]}"; do
    if ! execute_module "$phase"; then
      echo "Installation failed at phase: $phase"
      echo "Dusk Docker Container" "ERROR"
      exit 1
    fi
  done

  echo "Dusk Docker Container" "SUCCESS"

  }


# =============================================================================
# SCRIPT EXECUTION
# =============================================================================
# Check if script is being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Script is being executed directly
  # Check if we're in the right directory
  if [[ ! -d "$MODULES_DIR" ]]; then
    echo "Error: modules directory not found. Please run from the project root."
    echo "Expected modules directory at: $MODULES_DIR"
    exit 1
  fi

  if [[ ! -d "$CONFIG_DIR" ]]; then
  echo "Error: config directory not found. Please run from the project root."
  echo "Expected config directory at: $CONFIG_DIR"
  exit 1
  fi

  # Check for root privileges
  if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    echo "Try: sudo $0 $*"
    exit 1
  fi

  # Run main installation
  main_installation
fi
