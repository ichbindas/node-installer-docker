# Directory Overview

## Environment files (config/)
Use `cp *.env.example *.env` to create your own `.env` files.

[dusk.env.example](../config/dusk.env.example): Contains environment variables for the Dusk application, including database connection details, API keys, and other configuration settings.

[hetzner-firewall.env.example](../config/hetzner-firewall.env.example): Contains environment variables for configuring the Hetzner firewall, including API keys, firewall rules, and other settings.


## Dockerfile (config/)

[Dockerfile.runtime](../config/templates/Dockerfile.runtime): Template for a Dockerfile used to build a runtime environment for a Python application. Includes instructions to install dependencies, copy application files, and configure the runtime environment.


## Templates (config/templates)

[app.py](../config/templates/app.py): Template for the main application file in a Flask application. Includes the basic structure and configuration for a Flask app, including routes, database connections, and other essential components.

[docker-compose.yml.template](../config/templates/docker-compose.yml.template): Template for a Docker Compose file. Defines the services, networks, and volumes required to run a multi-container Docker application.

[docker-compose.config.yml.template](../config/templates/docker-compose-config.yml.template): Template for the configuration of a Docker Compose file. Defines system properties such as image and volume_prefix as well as ports and sysctl values.

[flask-api.service](../config/templates/flask-api.service): Template for a systemd service file for running a Flask API application. Includes configuration for starting, stopping, and managing the Flask API service.


## Scripts (config/src)

[docker-entrypoint.sh](../config/templates/docker-entrypoint.sh): Script used as the entrypoint for a Docker container. Performs initial setup tasks, such as creating directories, setting permissions, and starting services, before the main application starts.

[docker-install-wrapper.sh](../config/templates/docker-install-wrapper.sh): Wrapper script for installing Docker on a system. Includes commands to install Docker, configure Docker to start on boot, and set up any necessary user permissions.