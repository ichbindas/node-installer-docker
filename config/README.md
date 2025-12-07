# Directory Overview

## Example Environment and Configuration files (config/examples)
Copy `cp` example `.env` files into `/config` and edit them.

[dusk.env.example](../config/examples/dusk.env.example): Contains environment variables for the Dusk application, including database connection details, API keys, and other configuration settings.

[hetzner-firewall.env.example](../config/examples/hetzner-firewall.env.example): Contains environment variables for configuring the Hetzner firewall, including API keys, firewall rules, and other settings.

[docker-compose-config.yml.example](../config/examples/docker-compose-config.yml.example): Template for the configuration of a Docker Compose file. Defines system properties such as image and volume_prefix as well as ports and sysctl values.
[icmp-config.env.example](../config/examples/icmp-config.env.example)

[docker-compose.yml.example](../config/templates/docker-compose.yml.template): Template for a Docker Compose file. Defines the services, networks, and volumes required to run a multi-container Docker application.

[docker-compose-config.yml.example](../config/templates/docker-compose-config.yml.example): Template for the configuration of a Docker Compose file. Defines system properties such as image and volume_prefix as well as ports and sysctl values.

## Scripts (config/src)

[docker-entrypoint.sh](../config/src/docker-entrypoint.sh): Script used as the entrypoint for a Docker container. Performs initial setup tasks, such as creating directories, setting permissions, and starting services, before the main application starts.

[docker-install-wrapper.sh](../config/src/docker-install-wrapper.sh): Wrapper script for installing Docker on a system. Includes commands to install Docker, configure Docker to start on boot, and set up any necessary user permissions.

## Dockerfile (config/)

[Dockerfile.runtime](../config/Dockerfile.runtime): Template for a Dockerfile used to build a runtime environment for a Python application. Includes instructions to install dependencies, copy application files, and configure the runtime environment.
