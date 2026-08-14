# Container launch
```bash
docker compose -d up
```
# Vault initialisation and unseal
```bash
docker exec -it vault export VAULT_SKIP_VERIFY=true -tls-skip-verify

# Save the 5 keys and the root token
docker exec -it vault vault operator init

# Run the next command 3 times and provide a unseal key each time
docker exec -it vault-server vault operator unseal

# When unseal connect with root token
docker exec -it vault-server vault login

# Activation of the secret motor and transit
docker exec -it vault-server vault secrets enable -path=secret kv-v2
vault auth enable approle
vault secrets enable transit

# Key creation
vault write -f transit/keys/cosign-key type=ecdsa-p256
```
# Secrets creation
Use this command to create secret for scaleway/backend, scaleway/access/terraform and defectdojo
Please use vault.md
```bash
vault kv put secret/<secret>/<path>
token=12345-xyz-secret token2 = 153247-azr-secret
```
# Policies and appRole
Use these commands to create the policy and get the role and secret id for terraform-policy, jenkins_push and jenkins_pull
```bash
# Policy creation
vault policy write cosign-policy /vault/policies/<policy_name>.hcl
# AppRole creation
vault write auth/approle/role/<role_name> \
    secret_id_ttl=10m \
    token_ttl=15m \
    token_max_ttl=30m \
    secret_id_num_uses=1 \
    policies="<policy_name>"
# Role id and secret id creation
vault read -field=role_id auth/approle/role/<role_name>/role-id
vault write -f -field=secret_id auth/approle/role/<role_name>/secret-id
```

# Revoke all token for AppRole (if necessary)
vault token revoke -mode=path auth/approle


sudo docker exec -u 0 -it jenkins keytool -import -alias vault-cert -file /tmp/vault.crt -keystore opt/java/openjdk/lib/security/cacerts -storepass changeit -noprompt

sudo docker restart jenkins


