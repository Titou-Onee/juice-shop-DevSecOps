# Scaleway access
path "secret/data/scaleway/access/terraform" {
  capabilities = ["read"]
}

# Backend credentials
path "secret/data/scaleway/backend" {
  capabilities = ["read"]
}

# Backend connection
path "secret/data/scaleway/pg_conn_str" {
  capabilities = ["create","read","update","patch","delete"]
}

# Jenkins push registry
path "secret/data/scaleway/jenkins_push" {
  capabilities = ["create", "read", "update", "patch","delete"]
}

# Jenkins pull registry and container image update
path "secret/data/scaleway/jenkins_pull" {
  capabilities = ["create", "read", "update", "patch","delete"]
}


path "secret/metadata/scaleway/*" {
  capabilities = ["list","read"]
}

path "secret/metadata/*" {
  capabilities = ["list"]
}
path "auth/token/create" {
  capabilities = ["update"]
}