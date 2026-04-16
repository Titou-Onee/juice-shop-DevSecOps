# Cosign keys
path "secret/data/cosign/*" {
  capabilities = ["read"]
}
path "secret/metadata/cosign/*" {
  capabilities = ["list", "read"]
}

# Scaleway image registry
path "secret/data/scaleway/registry/*" {
  capabilities = ["read"]
}
path "secret/metadata/scaleway/registry/*" {
  capabilities = ["list", "read"]
}

# DefectDojo  API key
path "secret/data/defectdojo" {
  capabilities = ["read"]
}
path "secret/metadata/defectdojo" {
  capabilities = ["list", "read"]
}

path "secret/metadata/*" {
  capabilities = ["list"]
}