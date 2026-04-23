# Scaleway and image registry connection
path "secret/data/scaleway/jenkins_push" {
  capabilities = ["read"]
}
path "secret/metadata/scaleway/jenkins_push" {
  capabilities = ["list", "read"]
}

# DefectDojo  API key
path "secret/data/defectdojo" {
  capabilities = ["read"]
}
path "secret/metadata/defectdojo" {
  capabilities = ["list", "read"]
}

# Cosign

path "transit/sign/cosign-key" {
  capabilities = ["update"]
}
path "transit/verify/cosign-key" {
  capabilities = ["update"]  
}

path "transit/keys/cosign-key" {
  capabilities = ["read"]
}

path "transit/export/cosign-key" {
  capabilities = ["deny"]
}

path "secret/metadata/*" {
  capabilities = ["list"]
}