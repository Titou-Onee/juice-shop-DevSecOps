# Scaleway and image registry connection
path "secret/data/scaleway/jenkins_push" {
  capabilities = ["read"]
}
path "secret/metadata/scaleway/jenkins_push" {
  capabilities = ["list", "read"]
}

# Cosign

path "secret/data/cosign/keys" {
  capabilities = ["read"]
}
path "secret/metadata/cosign/keys" {
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