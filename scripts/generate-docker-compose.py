#!/usr/bin/env python3
"""
Generate docker-compose.yml for multiple Dusk nodes
Automatically assigns unique ports to each node and sets resource limits

Usage:
./scripts/generate-docker-compose.py --nodes 1 --network mainnet --output docker-compose.yml

Configuration:
The script uses a configuration file (config/docker-compose-config.yml) for default values.
You can override these values with command-line arguments.

Example config/docker-compose-config.yml:
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
cpu_limit: 2.0
memory_limit: 2G
storage_limit_rusk: 19G # stores state
storage_limit_data: 1G # stores keys, wallet config, etc.
docker_network_name: "dusk-net"
"""

import argparse
import yaml
import sys
import logging

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

def load_config(config_path: str ="config/docker-compose-config.yml"):
    """Load configuration from YAML file"""
    try:
        with open(config_path, 'r') as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        logger.warning(f"Config file not found at {config_path}, using defaults")
        return {}
    except yaml.YAMLError as e:
        logger.error(f"Error parsing config file: {e}")
        sys.exit(1)

def generate_compose(num_nodes, config, network="mainnet", feature="default"):
    """Generate docker-compose configuration for N nodes"""

    # Set default resource limits if not specified
    cpu_limit = config.get('cpu_limit', 2.0)
    memory_limit = config.get('memory_limit', '2G')
    docker_network_name = config.get('docker_network_name', 'dusk-net')

    compose = {
        'version': '3.8',
        'services': {},
        'volumes': {},
        'networks': {
            docker_network_name: {
                'name': docker_network_name,
                'driver': 'bridge',
            }
        }
    }

    for i in range(1, num_nodes + 1):
        node_name = f"{config.get('volume_prefix', 'dusk-node')}-{i}"
        host_p2p = config.get('base_p2p_port', 18080) + i
        host_rpc = config.get('base_rpc_port', 19000) + i

        service = {
            'build': {
                'context': '.',
                'dockerfile': config.get('dockerfile_path', 'config/Dockerfile.runtime'),
                'args': {
                    'BASE_IMAGE': config.get('base_image','ubuntu:24.04')
                }
            },
            'container_name': node_name,
            'restart': 'unless-stopped',
            'ports': [
                f"{host_p2p}:8080",  # P2P
                f"{host_rpc}:9000"   # RPC
            ],
            'volumes': [
                f"{node_name}-data:/home/dusk/.dusk",
                f"{node_name}-rusk:/opt/dusk/rusk"
            ],
            'environment': [
                f"DUSK_NETWORK={network}",
                f"DUSK_FEATURE={feature}",
                "DUSK_USER=dusk",
                "RUST_LOG=info"
            ],
            'sysctls': config['dusk_sysctls'],
            'deploy': {
                'resources': {
                    'limits': {
                        'cpus': cpu_limit,
                        'memory': memory_limit
                    }
                }
            },
            'networks': [docker_network_name],
        }

        compose['services'][node_name] = service

        compose['volumes'][f"{node_name}-data"] = {
            'driver_opts': {
                    'size': config.get('storage_limit_data', '1G')
                }
        }

        compose['volumes'][f"{node_name}-rusk"] = {
            'driver_opts': {
                    'size': config.get('storage_limit_rusk', '19G')
                }
        }

    return compose

def main():
    parser = argparse.ArgumentParser(
        description='Generate docker-compose.yml for Dusk nodes',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument('--nodes', type=int, default=3, help='Number of nodes')
    parser.add_argument('--network', choices=['mainnet', 'testnet'], default='mainnet', help='Network type')
    parser.add_argument('--feature', choices=['default', 'archive'], default='default', help='Node feature')
    parser.add_argument('--base-p2p', type=int, help='Base port for P2P')
    parser.add_argument('--base-rpc', type=int, help='Base port for RPC')
    parser.add_argument('--cpu-limit', type=float, help='CPU limit per node')
    parser.add_argument('--memory-limit', type=str, help='Memory limit per node (e.g., 4G)')
    parser.add_argument('--storage-limit-rusk', type=str, help='Storage limit for rusk data per node')
    parser.add_argument('--storage-limit-data', type=str, help='Storage limit for config data per node')
    parser.add_argument('--output', default='docker-compose.yml', help='Output file')
    parser.add_argument('--config', default='config/docker-compose-config.yml', help='Configuration file path')

    args = parser.parse_args()

    if args.nodes < 1:
        logger.error("Error: --nodes must be at least 1")
        sys.exit(1)

    # Load configuration
    config = load_config(args.config)

    # Override config with command-line arguments if provided
    if args.base_p2p is not None:
        config['base_p2p_port'] = args.base_p2p
    if args.base_rpc is not None:
        config['base_rpc_port'] = args.base_rpc
    if args.cpu_limit is not None:
        config['cpu_limit'] = args.cpu_limit
    if args.memory_limit is not None:
        config['memory_limit'] = args.memory_limit
    if args.storage_limit_rusk is not None:
        config['storage_limit_rusk'] = args.storage_limit_rusk
    if args.storage_limit_data is not None:
        config['storage_limit_data'] = args.storage_limit_data

    logger.info(f"Generating docker-compose.yml for {args.nodes} nodes ({args.network}, {args.feature})...")

    compose = generate_compose(
        args.nodes,
        config=config,
        network=args.network,
        feature=args.feature
    )

    try:
        with open(args.output, 'w') as f:
            yaml.dump(compose, f, default_flow_style=False, sort_keys=False)
        logger.info(f"✓ Generated {args.output}")
        logger.info(f"  Nodes: {args.nodes}")
        logger.info(f"  P2P ports: {config['base_p2p_port'] + 1} - {config['base_p2p_port'] + args.nodes}")
        logger.info(f"  RPC ports: {config['base_rpc_port'] + 1} - {config['base_rpc_port'] + args.nodes}")
        logger.info(f"  CPU limit: {config.get('cpu_limit', 'Not specified')}")
        logger.info(f"  Memory limit: {config.get('memory_limit', 'Not specified')}")
        logger.info(f"  Rusk Storage limit: {config.get('storage_limit_rusk', 'Not specified')}")
        logger.info(f"  Data Storage limit: {config.get('storage_limit_data', 'Not specified')}")
    except IOError as e:
        logger.error(f"Error writing to file {args.output}: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()