#!/bin/bash
# Docker-specific wrapper for node-installer.sh
# Removes systemctl calls that don't work in containers
# Makes sysctl non-fatal (sysctls passed via docker-compose instead)

set -e

echo "Running Dusk node installer in Docker mode..."

# Source the original installer but skip systemctl calls
INSTALLER_SCRIPT="/tmp/node-installer.sh"

# Create a modified version without systemctl
# Also make sysctl failures non-fatal since we handle it via docker-compose sysctls
sed \
  -e '/systemctl stop rusk/d' \
  -e '/systemctl enable rusk/d' \
  -e '/systemctl daemon-reload/d' \
  -e 's/sysctl -p/sysctl -p || true  # Docker sysctls handled via docker-compose/' \
  "$INSTALLER_SCRIPT" > /tmp/node-installer-docker.sh # rename script so that the wrapped intention is more visible

chmod +x /tmp/node-installer-docker.sh

# Run the modified installer
/tmp/node-installer-docker.sh "$@"

echo "Installer completed successfully!"
