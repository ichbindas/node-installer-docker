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
  log_info "📋 Loading configuration from dusk.env"
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
    --verbose)
      VERBOSE=true
      LOG_LEVEL=$LOG_LEVEL_DEBUG
      shift
      ;;
    --add-nodes)
      if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
        ADD_NODES="$2"
        shift 2
      else
        log_error "--add-nodes requires a number"
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
      log_error "Unknown option: $1"
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
--list-containers  List existing containers
--skip-validation  Skip pre-installation validation
--verbose          Enable verbose logging
--help, -h         Show this help message

Installation Phases:
1. Docker Setup: Configures Docker environment
2. Install Dusk Node: Sets up Dusk node components
3. Fast Sync: Optional state synchronization (when --fast-sync flag is used)

Examples:
sudo $0                    # Normal installation (1 container)
sudo $0 --add-nodes 3       # Install with 3 containers
sudo $0 --fast-sync         # Install with fast-sync
sudo $0 --skip-validation  # Skip pre-installation checks (use with caution)
sudo $0 --add-nodes 2       # Add 2 more containers to existing setup
sudo $0 --list-containers   # List existing containers
sudo $0 --verbose           # Verbose logging
EOF
}

# Check if module exists
check_module_exists() {
  local module_name=$1
  local module_path="$MODULES_DIR/$module_name.sh"

  if [[ -f "$module_path" ]]; then
    log_debug "Module found: $module_name at $module_path"
    return 0
  else
    log_error "Module not found: $module_name"
    log_error "Expected location: $module_path"
    log_error "Please ensure all required modules are present in $MODULES_DIR"
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

  log_section_start "Module: $module_name"

  # Check if module exists
  if ! check_module_exists "$module_name"; then
    log_section_end "Module: $module_name" "ERROR"
    return 1
  fi

  # Skip fast-sync if not enabled
  if [[ "$module_name" == "03-fast-sync" && "$FAST_SYNC_ENABLED" != "true" ]]; then
    log_info "ℹ️ Skipping fast-sync (not enabled)"
    log_section_end "Module: $module_name" "SKIPPED"
    return 0
  fi

  start_time=$(date +%s)
  log_info "🚀 Starting module: $module_name"

  # Execute module with timeout
  if timeout "$timeout" bash "$module_path"; then
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    log_info "Module $module_name completed successfully in $duration seconds"
    log_section_end "Module: $module_name" "SUCCESS"
    return 0
  else
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    log_error "Module $module_name failed after $duration seconds"
    log_section_end "Module: $module_name" "ERROR"
    return 1
    fi
  fi
}

# Enhanced rollback function
rollback_installation() {
  local failed_module=$1
  log_error "🔄 Rolling back installation due to failure in module: $failed_module"

  # Stop Docker containers
  if [[ -f "/opt/dusk/docker-compose.yml" ]]; then
    log_info "Stopping Docker containers"
    cd /opt/dusk 2>/dev/null || true

    if command -v docker-compose >/dev/null 2>&1; then
      log_info "🔧 Running: docker-compose down"
      docker-compose down 2>/dev/null || true
    elif docker compose version >/dev/null 2>&1; then
      log_info "🔧 Running: docker compose down"
      docker compose down 2>/dev/null || true
    fi
  fi

  # Remove created directories if they're empty
  if [[ -d "$DUSK_BASE_DIR" ]]; then
    if [[ -z "$(ls -A "$DUSK_BASE_DIR")" ]]; then
      log_info "🗑️ Removing empty installation directory: $DUSK_BASE_DIR"
      rmdir "$DUSK_BASE_DIR" 2>/dev/null || true
    else
      log_info "ℹ️ Keeping non-empty installation directory: $DUSK_BASE_DIR"
    fi
  fi

  log_error "🔄 Rollback completed. Manual cleanup may be required for non-empty directories."
}


# Enhanced container listing with filtering options
list_containers() {
  log_info "📋 Listing existing Dusk node containers..."

  local compose_cmd
  local filter_status=""
  local filter_name="dusk-node"

  # Determine docker-compose command
  if command -v docker-compose >/dev/null 2>&1; then
    compose_cmd="docker-compose"
  elif docker compose version >/dev/null 2>&1; then
    compose_cmd="docker compose"
  else
    log_error "Docker Compose not found"
    return 1
  fi

  # Show Docker Compose services if available
  if [[ -f "/opt/dusk/docker-compose.yml" ]]; then
    cd /opt/dusk 2>/dev/null || return 1
    echo ""
    echo "Docker Compose Services:"
    $compose_cmd -f /opt/dusk/docker-compose.yml ps
    echo ""
  else
    log_info "ℹ️ No docker-compose.yml found"
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
    log_error "Invalid network specified: $NETWORK. Must be 'mainnet' or 'testnet'"
    return 1
  fi

  return 0
}

# Check disk space requirements
check_disk_space() {
  local required_space_gb=50  # Base requirement

  # Calculate total required space
  local total_required_gb=$((node_space_gb * ADD_NODES))

  # Get available space in GB
  local available_space_gb=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')

  if [[ "$available_space_gb" -lt "$total_required_gb" ]]; then
    log_error "Insufficient disk space"
    log_error "Required: ${total_required_gb}GB, Available: ${available_space_gb}GB"
    return 1
  fi

  log_info "Disk space check passed (${available_space_gb}GB available)"
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
    log_error "Insufficient memory"
    log_error "Required: ${total_required_mb}MB, Available: ${available_mem_mb}MB"
    return 1
  fi

  log_info "Memory check passed (${available_mem_mb}MB available)"
  return 0
}

# Check network connectivity
check_network_connectivity() {
  # Check basic internet connectivity
  if ! ping -c 1 8.8.8.8 &> /dev/null; then
    log_error "No internet connectivity detected"
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
    log_error "Unable to reach Dusk network nodes"
    log_error "Check your network configuration and firewall settings"
    return 1
  fi

  log_info "Network connectivity check passed"
  return 0
}

# Check Docker installation
check_docker_installation() {
  if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    return 1
  fi

  if ! docker info &> /dev/null; then
    log_error "Docker daemon is not running"
    return 1
  fi

  log_info "Docker installation check passed"
  return 0
}

# Check Docker Compose installation
check_docker_compose_installation() {
  if command -v docker-compose &> /dev/null; then
    log_info "Using docker-compose v$(docker-compose| awk '{print $4}')"
    return 0
  elif docker compose version &> /dev/null; then
    log_info "Using docker compose v$(docker compose)"
    return 0
  else
    log_error "Docker Compose is not installed"
    return 1
  fi
}

# Check installation directory
check_installation_directory() {
  if [[ -d "$DUSK_BASE_DIR" ]]; then
    if [[ ! -w "$DUSK_BASE_DIR" ]]; then
      log_error "Installation directory not writable: $DUSK_BASE_DIR"
      return 1
    fi
  else
    if ! mkdir -p "$DUSK_BASE_DIR" &> /dev/null; then
      log_error "Unable to create installation directory: $DUSK_BASE_DIR"
      return 1
    fi
  fi

  log_info "Installation directory check passed ($DUSK_BASE_DIR)"
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
    log_error "Some required installation modules are missing"
    return 1
  fi

  log_info "Module check passed"
  return 0
}

# Pre-installation validation function
run_pre_installation_checks() {
  local validation_passed=true

  log_section_start "Pre-Installation Checks"

  # Validate network
  if ! validate_network; then
    log_error "Network validation failed"
    validation_passed=false
  fi

  # Check disk space
  if ! check_disk_space; then
    log_error "Insufficient disk space"
    validation_passed=false
  fi

  # Check memory requirements
  if ! check_memory_requirements; then
    log_error "Insufficient memory"
    validation_passed=false
  fi

  # Check network connectivity
  if ! check_network_connectivity; then
    log_error "Network connectivity issues detected"
    validation_passed=false
  fi

  # Check Docker installation
  if ! check_docker_installation; then
    log_error "Docker not properly installed"
    validation_passed=false
  fi

  # Check Docker Compose installation
  if ! check_docker_compose_installation; then
    log_error "Docker Compose not properly installed"
    validation_passed=false
  fi

  # Check if installation directory exists and is writable
  if ! check_installation_directory; then
    log_error "Installation directory issues"
    validation_passed=false
  fi

  # Check if required modules exist
  if ! check_required_modules; then
    log_error "Required installation modules are missing"
    validation_passed=false
  fi

  # Check if we're running as root (required for some operations)
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    validation_passed=false
  fi

  if [[ "$validation_passed" == "false" ]]; then
    log_section_end "Pre-Installation Checks" "FAILED"
    return 1
  fi

  log_section_end "Pre-Installation Checks" "PASSED"
  return 0
}


# =============================================================================
# MAIN INSTALLATION PROCESS
# =============================================================================

# Show installation summary before starting
show_installation_summary() {
  log_info "📋 Installation Summary:"
  log_info "  - Nodes to install: $ADD_NODES"
  log_info "  - Network: $NETWORK"
  log_info "  - Base Directory: $DUSK_BASE_DIR"
  log_info "  - Fast Sync: $([ "$FAST_SYNC_ENABLED" == "true" ] && echo "Enabled" || echo "Disabled")"
  log_info "🔧 Starting installation process..."
}


# Show completion message with enhanced information
show_completion_message() {
  echo ""
  log_info "Installation completed successfully!"
  log_info ""

  # Show installation summary
  log_info "Installation Summary:"
  log_info "  - Nodes installed: $ADD_NODES"
  log_info "  - Network: $NETWORK"
  log_info "  - Base Directory: $DUSK_BASE_DIR"
  log_info "  - Fast Sync: $([ "$FAST_SYNC_ENABLED" == "true" ] && echo "Enabled" || echo "Disabled")"
  log_info ""

  # Show container status
  log_info "📋 Container Status:"
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
    log_warn "ℹ️ No docker-compose.yml found at $DUSK_BASE_DIR"
  fi

  # Show node status
  log_info "📋 Node Status:"
  if [[ -d "$DUSK_BASE_DIR/nodes" ]]; then
    for node_dir in "$DUSK_BASE_DIR/nodes"/*; do
      if [[ -d "$node_dir" ]]; then
        node_name=$(basename "$node_dir")
        log_info "  - $node_name: $(get_node_status "$node_dir")"
      fi
    done
  else
    log_warn "ℹ️ No nodes directory found at $DUSK_BASE_DIR/nodes"
  fi

  log_info ""
  log_info "🔧 Useful Commands:"
  log_info "  dusk-start              # Start all nodes"
  log_info "  dusk-stop               # Stop all nodes"
  log_info "  dusk-restart            # Restart all nodes"
  log_info "  dusk-status             # Show node status"
  log_info "  dusk-logs               # View logs"
  log_info ""
  log_info "  cd $DUSK_BASE_DIR && $compose_cmd ps    # View container status"
  log_info "  cd $DUSK_BASE_DIR && $compose_cmd logs # View all logs"
  log_info ""
}

# Get node status
get_node_status() {
  local node_dir=$1

  if [[ -n "$compose_cmd" ]]; then
    local container_name=$(basename "$node_dir")
    local container_status=$($compose_cmd ps -q "$container_name" | xargs $compose_cmd inspect -f '{{.State.Status}}' 2>/dev/null)
    if [[ -n "$container_status" ]]; then
      echo "$container_status"
      return 0
    fi
  fi echo "Unknown"

# Main installation function
main_installation() {
  log_section_start "Sozu Dusk Container"

  # Display installation summary
  show_installation_summary

  # Pre-installation validation
  log_info "🔍 Running pre-installation validation..."
  if ! run_pre_installation_checks ; then
    log_error "Pre-installation validation failed"
    log_section_end "Sozu Dusk Container" "ERROR"
    exit 1
  fi

  # Execute each phase
  for phase in "${PHASES[@]}"; do
    if ! execute_module "$phase"; then
      log_error "Installation failed at phase: $phase"
      log_section_end "Sozu Dusk Container" "ERROR"
      exit 1
    fi
  done

  log_section_end "Sozu Dusk Container" "SUCCESS"

  }
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