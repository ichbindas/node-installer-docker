# Dusk Node Conifguration

## Docker Configuration

This repository contains the necessary files to set up and manage Dusk nodes using Docker.

### Files
1. **config/Dockerfile.runtime**: Dockerfile with build instructions for a container.
2. **config/examples/docker-compose-config.yml.example**: Configuration file for the Docker Compose generator script.
3. **scripts/generate-docker-compose.py**: A Python script to generate a docker-compose.yml file based on the configuration.

### Usage

1. ```zsh
   cp config/templates/docker-compose-config.yml.template config/docker-compose-config.yml
   ```
   and modify the configuration for docker containers.
2. Install the required dependencies:
   ```zsh
   pip install pyyaml
   ```
3. Run the script to generate a docker-compose.yml file:
   ```zsh
   python scripts/generate-docker-compose.py --nodes 5 --network mainnet --output docker-compose.yml
   ```
   Replace `5` with the number of nodes you want to create, and `mainnet` with the network type (`mainnet` or `testnet`).

### Configuration

The `config/examples/docker-compose-config.yml.example` file contains the default configuration for the Docker Compose generator script. You can override these values with command-line arguments.

Example configuration:
```yaml
---
base_image: "ubuntu:24.04"
dockerfile_path: "config/Dockerfile.runtime"
volume_prefix: "dusk-node"
base_p2p_port: 18080
base_rpc_port: 19000
dusk_sysctls:
  - "net.core.rmem_max=50000000"
  - "net.core.rmem_default=20000000"
  - "net.ipv4.udp_mem=262144 327680 393216"
  - "net.ipv4.udp_rmem_min=4096"
  - "net.core.netdev_max_backlog=2000"
  - "net.core.wmem_default=20000000"
  - "net.core.wmem_max=50000000"
# Resource limits
cpu_limit: 2.0
memory_limit: 4G
storage_limit: 50G
```