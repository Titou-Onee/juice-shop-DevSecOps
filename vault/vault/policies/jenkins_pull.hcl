# Cosign public key
path "secret/data/cosign/keys_verify" {
  capabilities = ["read"]
}
path "secret/metadata/cosign/keys_verify" {
  capabilities = ["list", "read"]
}

# Scaleway image registry connection
path "secret/data/scaleway/jenkins_pull" {
  capabilities = ["read"]
}
path "secret/metadata/scaleway/jenkins_pull" {
  capabilities = ["list", "read"]
}

# DefectDojo  API key
path "secret/data/defectdojo" {
  capabilities = ["read"]
}
path "secret/metadata/defectdojo" {
  capabilities = ["list", "read"]
}


path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}