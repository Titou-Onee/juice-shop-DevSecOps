If your tls certificates are auto-signed :

export VAULT_SKIP_VERIFY=true

docker exec -it vault vault operator init -tls-skip-verify

docker exec -it vault vault operator unseal -tls-skip-verify
then provide 3 keys

export VAULT_ADDR="https://127.0.0.1:8200"
export VAULT_TOKEN=<YOUR_ROOT_TOKEN>

Activation of the secret motor
vault secrets enable -path=secret kv-v2

Create a simple secret and read it :
vault kv put secret/test/first-secret token=12345-xyz-secret

vault kv get secret/test/first-secret

vault policy write jenkins-policy jenkins-policy.hcl

# 1. Activer la méthode d'auth AppRole
vault auth enable approle

# 2. Créer le rôle "jenkins-role" lié à notre policy
vault write auth/approle/role/jenkins-role \
    token_ttl=1h \
    token_max_ttl=4h \
    policies="jenkins-polic

sudo docker cp vault/tls/cert.pem jenkins:/tmp/vault.crt


sudo docker exec -u 0 -it jenkins keytool -import -alias vault-cert -file /tmp/vault.crt -keystore opt/java/openjdk/lib/security/cacerts -storepass changeit -noprompt

sudo docker restart jenkins


vault policy write terraform-policy vault/policies/terraform-policy.hcl

vault write auth/approle/role/jenkins-role \
    token_ttl=1h \
    token_max_ttl=4h \
    policies="jenkins-policy

    vault read auth/approle/role/jenkins-role/role-id

    vault write -f auth/approle/role/jenkins-role/secret-id