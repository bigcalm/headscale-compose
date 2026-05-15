Prompts given to OpenCode to generate the "headscale-compose" project:
* Create a full set of configuration files that will run headscale, a good web ui for headscale, and caddy to keep everything on the same domain. Do so using "docker compose" for the containers.
* Create a wrapper bash script for the headscale binary within the headscale container. Avoid the use of "docker exec", a lot of these commands can be done via "docker compose". Write a README.md describing how to use this project.
* I would prefer to use bound directories to store data, rather than docker volumes
* Update the README.md, at the top of the file, to state that this mini project was created using OpenCode with the Big Pickle model. Include an AGENTS.md file for the project as well.
* Let's switch back to using docker volumes for data storage. Write bash scripts for creating a local backup of all data, and one to restore, so that if the server is lost, it can be rebuilt quickly
* We should use versioned services, rather than "latest" and "stable". Though it would be good to work out what the latest/stable version is for each service. The backup and restore system needs to also manage the manually edited config files. Lastly, the backups should indicate the version of the service they relate to.
* 
