todo: 
- link the files
- don't hardcode ADD_NODES in main-installer.sh -> we create a docker-compose.yml with the required number of nodes, and so we shouldn't also have to think about setting the number of nodes in the env.
- implement fast_sync logic by utilizing the offical script: node-installer/bin/download_state.sh
- docker-compose.yml is supposed to be in opt/dusk/

# Process
Entrypoint: `scripts/main_installer.sh` 

-> `scripts/modules/01-docker-setup.sh`

-> `docker-compose.yml`

-> `config/Dockerfile.runtime`

-> `config/src/docker-entrpoint.sh`

-> `config/src/docker-installer-wrapper.sh` modifies `node-installer/node-installer.sh` to disable (?) systemctl and sysctl and runs inside the container 

-> `tmp/node-installer-docker.sh` -> Fertig