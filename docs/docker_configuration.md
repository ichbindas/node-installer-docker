# Dusk Node Docker Configuration

This repository contains the necessary files to set up and manage Dusk nodes using Docker.

## Files

1. **docker-compose.yml.template**: A template file for configuring Dusk nodes with Docker Compose.
2. **config/docker-compose-config.yml**: Configuration file for the Docker Compose generator script.
3. **scripts/generate-docker-compose.py**: A Python script to generate a docker-compose.yml file based on the configuration.

## Usage

### Using the Template

1. Copy the `docker-compose.yml.template` file to `docker-compose.yml`: `cp config/templates/docker-compose-config.yml.template config/docker-compose-config.yml`
2. Modify the file to suit your needs. You can add more nodes by duplicating the `dusk-node` service and updating the port mappings and volume names.
3. Start the Dusk nodes using Docker Compose:
   ```bash
   docker-compose up -d
   ```

### Using the Script

1. Ensure you have Python 3 installed.
2. Install the required dependencies:
   ```bash
   pip install pyyaml
   ```
3. Run the script to generate a docker-compose.yml file:
   ```bash
   python scripts/generate-docker-compose.py --nodes 5 --network mainnet --output docker-compose.yml
   ```
   Replace `5` with the number of nodes you want to create, and `mainnet` with the network type (`mainnet` or `testnet`).

### Configuration

The `config/docker-compose-config.yml` file contains the default configuration for the Docker Compose generator script. You can override these values with command-line arguments.

Example configuration:
```yaml
---
base_image: "ubuntu:24.04"
dockerfile_path: "config/templates/Dockerfile.runtime"
volume_prefix: "dusk-node"
base_p2p_port: 8000
base_rpc_port: 9000
dusk_sysctls:
  - "net.core.rmem_max=50000000"
  - "net.core.rmem_default=20000000"
  - "net.ipv4.udp_mem=262144 327680 393216"
  - "net.ipv4.udp_rmem_min=4096"
  - "net.core.netdev_max_backlog=2000"
  - "net.core.wmem_default=20000000"
  - "net.core.wmem_max=50000000"
```

### Paths

Before using the files, make sure to set the correct paths:

1. **Dockerfile.runtime**: Update the `dockerfile_path` in the configuration file to point to the correct path of your Dockerfile.runtime.
2. **Template File**: Ensure the template file is in the correct directory. You might need to update the paths in the template file to match your project structure.
3. **Script**: Update the script path in the README to match the location of your script.

### Notes

- The script and template file are designed to simplify the setup and management of Dusk nodes using Docker.
- The template file provides a starting point for manual configurations, while the script offers more flexibility and automation.
- Ensure you have the necessary permissions and dependencies installed before using the files.
