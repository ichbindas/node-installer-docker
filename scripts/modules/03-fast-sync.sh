#!/bin/bash

# 🚀 Sozu Dusk Container - Fast-Sync Module
# Bootstraps nodes with latest published state to reduce sync time

# =============================================================================
# SOURCE UTILITIES
# =============================================================================

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/../utils"

# Source logging utilities
if [[ -f "$UTILS_DIR/logging.sh" ]]; then
    source "$UTILS_DIR/logging.sh"
    source "$UTILS_DIR/validation.sh"
else
    echo "❌ Error: logging.sh not found"
    exit 1
fi

# =============================================================================
# FAST-SYNC CONFIGURATION
# =============================================================================

# Configuration
DOCKER_COMPOSE_FILE="/opt/dusk/docker-compose.yml"
FAST_SYNC_ENABLED=${FAST_SYNC_ENABLED:-false}

# =============================================================================
# FAST-SYNC FUNCTIONS
# =============================================================================

# Check if fast-sync should run
should_run_fast_sync() {
    if [[ "$FAST_SYNC_ENABLED" != "true" ]]; then
        log_info "ℹ️ Fast-sync not enabled (use --fast-sync flag to enable)"
        return 1
    fi
    return 0
}

# Get list of Dusk node containers
get_dusk_containers() {
    # Determine docker-compose command
    local compose_cmd
    if command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    elif docker compose version >/dev/null 2>&1; then
        compose_cmd="docker compose"
    else
        log_error "❌ Docker Compose not found"
        return 1
    fi
    
    # Get list of services
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        local compose_dir=$(dirname "$DOCKER_COMPOSE_FILE")
        cd "$compose_dir" || return 1
        $compose_cmd -f "$DOCKER_COMPOSE_FILE" ps --services | grep "dusk-node" || true
    else
        # Fallback to docker ps
        docker ps --filter "name=dusk-node" --format "{{.Names}}" || true
    fi
}

# Ensure containers are running
ensure_containers_running() {
    log_info "🔍 Ensuring containers are running..."
    
    # Determine docker-compose command
    local compose_cmd
    if command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    elif docker compose version >/dev/null 2>&1; then
        compose_cmd="docker compose"
    else
        log_error "❌ Docker Compose not found"
        return 1
    fi
    
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        local compose_dir=$(dirname "$DOCKER_COMPOSE_FILE")
        cd "$compose_dir" || return 1
        
        if log_command "$compose_cmd -f $DOCKER_COMPOSE_FILE up -d" "Start containers"; then
            log_info "✅ Containers are running"
            return 0
        else
            log_error "❌ Failed to start containers"
            return 1
        fi
    else
        log_error "❌ docker-compose.yml not found: $DOCKER_COMPOSE_FILE"
        return 1
    fi
}

# Fast-sync a container
fast_sync_container() {
    local container_name=$1
    
    log_info "🔄 Fast-syncing container: $container_name"
    
    # Check if container is running
    if ! docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        log_warn "⚠️ Container $container_name is not running, skipping"
        return 1
    fi
    
    # Run download_state --list to see available states
    log_info "📋 Listing available states..."
    if docker exec "$container_name" download_state --list >/dev/null 2>&1; then
        log_info "✅ State list retrieved"
    else
        log_warn "⚠️ download_state --list failed (command may not be available)"
        log_warn "⚠️ Skipping fast-sync for $container_name"
        return 1
    fi
    
    # Run download_state to download latest state
    log_info "⬇️ Downloading latest state..."
    if log_command "docker exec $container_name download_state" "Download state for $container_name"; then
        log_info "✅ Fast-sync completed for $container_name"
        return 0
    else
        log_error "❌ Fast-sync failed for $container_name"
        return 1
    fi
}

# Fast-sync all containers
fast_sync_all_containers() {
    log_info "🔄 Fast-syncing all containers..."
    
    # Get list of containers
    local containers
    containers=$(get_dusk_containers)
    
    if [[ -z "$containers" ]]; then
        log_warn "⚠️ No Dusk node containers found"
        return 1
    fi
    
    local success_count=0
    local total_count=0
    
    # Fast-sync each container
    while IFS= read -r container; do
        [[ -z "$container" ]] && continue
        total_count=$((total_count + 1))
        
        if fast_sync_container "$container"; then
            success_count=$((success_count + 1))
        fi
    done <<< "$containers"
    
    log_info "📊 Fast-sync summary: $success_count/$total_count containers synced successfully"
    
    if [[ $success_count -eq $total_count ]]; then
        return 0
    else
        log_warn "⚠️ Some containers failed to fast-sync"
        return 1
    fi
}

# =============================================================================
# MAIN FAST-SYNC PROCESS
# =============================================================================

# Main fast-sync function
main_fast_sync() {
    log_section_start "Fast-Sync"
    
    # Check if fast-sync should run
    if ! should_run_fast_sync; then
        log_section_end "Fast-Sync" "SKIPPED"
        return 0
    fi
    
    log_info "🚀 Starting fast-sync process..."
    
    # Step 1: Ensure containers are running
    if ! ensure_containers_running; then
        log_section_end "Fast-Sync" "ERROR"
        return 1
    fi
    
    # Step 2: Fast-sync all containers
    if ! fast_sync_all_containers; then
        log_warn "⚠️ Fast-sync had issues, but continuing"
    fi
    
    log_section_end "Fast-Sync" "SUCCESS"
    log_info "✅ Fast-sync completed"
    log_info "ℹ️ Containers will continue running and sync with the network"
    
    return 0
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Check if script is being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    main_fast_sync
fi

