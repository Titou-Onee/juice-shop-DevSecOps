# Fast Run
## Create the ssh key for agent connection
```bash
ssh-keygen -t rsa -f jenkins_agent
```
Add the public key in Jenkins_env and .env

```bash
sudo docker compose up -d
```

Jenkins can be accessed at http://localhost:8080

# Connect Jenkins and Agent

Please use the tutorial : https://medium.com/@kitty2209/how-to-set-up-a-local-jenkins-environment-using-docker-and-ssh-agents-4b68ac1e13ef
