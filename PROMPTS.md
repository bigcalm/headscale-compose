Prompts given to OpenCode to generate the "headscale-compose" project:
* Create a full set of configuration files that will run headscale, a good web ui for headscale, and caddy to keep everything on the same domain. Do so using "docker compose" for the containers.
* Create a wrapper bash script for the headscale binary within the headscale container. Avoid the use of "docker exec", a lot of these commands can be done via "docker compose". Write a README.md describing how to use this project.
* I would prefer to use bound directories to store data, rather than docker volumes
* Update the README.md, at the top of the file, to state that this mini project was created using OpenCode with the Big Pickle model. Include an AGENTS.md file for the project as well.
* Let's switch back to using docker volumes for data storage. Write bash scripts for creating a local backup of all data, and one to restore, so that if the server is lost, it can be rebuilt quickly
* We should use versioned services, rather than "latest" and "stable". Though it would be good to work out what the latest/stable version is for each service. The backup and restore system needs to also manage the manually edited config files. Lastly, the backups should indicate the version of the service they relate to.
* Update the documentation to reference the repo for headscale-ui. Attribution is a must!
Container image versions can be set via environment variable. Let's move these things to the .env.example/.env file (and include information on how to find the latest versions for each). Update documentation to match this change.
* Container image versions are referenced incorrectly. Caddy tries to use "v2.11.3", but it should be without the "v" and just "2.11.3". Update the example env file, backup/restore scripts, and documentation.
* Another (older) instance of headscale creates magic DNS with the user name as part of the FQDN. Eg "iain-t480s.mobile.hs.example.com", where "mobile" is the username on headscale. This (newer) instance appears to omit the username, resulting in the likes of "iain-t480s.int.example.com". How do we alter the config so that magic DNS includes the username, and we get "iain-t380s.mobile.int.example.com"?
* That's a shame :( Thank you for clarifying this.
* Is "dns.extra_records_path" an option?
* Let's try that. Though it might be backed out if deemed convoluted.
* Update the agent documentation to ensure that SCM commits are never made unless the user requests it.
