# Dusk Node Configuration

## Docker Configuration

This repository contains the necessary files to set up and manage Dusk nodes using Docker.

### Files
1. **config/examples/docker-compose.yml.example**: Reference file for the `docker-compose.yml`
2. **config/examples/docker-compose-config.yml.example**: Configuration file for the `docker-compose.yml` generator script.
3. **scripts/generate-docker-compose.py**: A Python script to generate a docker-compose.yml file based on the configuration.
4. **config/Dockerfile.runtime**: Dockerfile with build instructions for a container.

### Usage

1. ```zsh
   cp config/examples/docker-compose-config.yml.example config/docker-compose-config.yml
   ```
   and modify the configuration for docker containers.
2. Install the required dependencies:
   ```zsh
   pip install pyyaml
   ```
3. Run the script to generate a docker-compose.yml file:
   ```zsh
   python scripts/generate-docker-compose.py --nodes 2 --network mainnet --output docker-compose.yml
   ```

**NOTE**: You need Python on the machine; alternatively copy the the docker-compose.yml.example to the config folder and adjust based on the desired number of nodes.

### Configuration

The `config/examples/docker-compose-config.yml.example` file contains the default configuration for the Docker Compose generator script. You can override these values with command-line arguments.

Example configuration:
```yaml
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
cpu_limit: 2.0
memory_limit: 2G
storage_limit_rusk: 19G # stores state
storage_limit_data: 1G # stores keys, wallet config, etc.
docker_network_name: "dusk-net"
```