storage "raft" {
  path    = "/vault/data"
  node_id = "vault_node_1" # Identifiant unique pour ce nœud
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_cert_file = "/vault/tls/cert.pem"
  tls_key_file  = "/vault/tls/key.pem"
  tls_min_version = "tls12"
  tls_disable_client_certs = "true"
}

api_addr     = "https://vault:8200"
cluster_addr = "https://vault:8201"
ui           = true

log_level = "debug"
log_file = "/vault/logs/vault-logs.log"