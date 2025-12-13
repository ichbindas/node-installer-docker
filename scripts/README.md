# Process of Running Docker Containers

- Overview of the [config](../config/README.md) directory. 
- Original Dusk Node Installer [README](../node-installer/README.md) file.

Follow these steps to create docker containers running dusk nodes.

1. Create docker-compose file

The steps below show how to prepare the desired number of nodes with a `docker-compose.yml`. (See [here](../docs/docker_configuration.md) for more)

- Copy and afterwards modify the configuration for docker containers.
   ```zsh
   cp config/example/docker-compose-config.yml.example config/docker-compose-config.yml
   ``` 
   
- Install the required dependencies:
   ```zsh
   pip install pyyaml
   ```

- Run the script to generate a docker-compose.yml file:
   ```zsh
   python scripts/generate-docker-compose.py --nodes 2 --network mainnet --output docker-compose.yml
   ```

**NOTE**: You need Python on the machine; alternatively copy the the docker-compose.yml.example to the config folder and adjust based on the desired number of nodes. `cp config/example/docker-compose.yml.example docker-compose.yml`


2. Installation

Now we can run `bash ./scripts/main-installer.sh` and the process should start.

