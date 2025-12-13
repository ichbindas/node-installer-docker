#!/bin/bash
set -e

# Run Docker-specific installer wrapper (removes systemctl calls)
echo "Running docker-entrypoint.sh"
echo "Running Dusk node installer in Docker mode..."
/tmp/docker-install-wrapper.sh --network "${DUSK_NETWORK:-mainnet}" --feature "${DUSK_FEATURE:-default}"

# Switch to dusk user and execute rusk
echo "Starting Rusk node..."
exec su - dusk -s /bin/bash -c "/opt/dusk/bin/rusk"

