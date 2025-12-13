todo: 
- link the files

# Process
Entrypoint: `scripts/main_installer.sh` 

-> `scripts/modules/01-docker-setup.sh`

-> `docker-compose.yml`

-> `config/Dockerfile.runtime`

-> `config/src/docker-entrpoint.sh`

-> `config/src/docker-installer-wrapper.sh` modifies `node-installer/node-installer.sh` to disable (?) systemctl and sysctl and runs inside the container 

-> `tmp/node-installer-docker.sh` -> Fertig