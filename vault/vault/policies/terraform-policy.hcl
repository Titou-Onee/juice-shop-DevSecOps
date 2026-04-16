# Scaleway
path "secret/data/scaleway/access" {
  capabilities = ["read"]
}
path "secret/metadata/scaleway/access" {
  capabilities = ["list", "read"]
}

path "secret/data/scaleway/backend" {
  capabilities = ["read"]
}
path "secret/metadata/scaleway/backend" {
  capabilities = ["list", "read"]
}

path "secret/data/scaleway/registry" {
  capabilities = ["read"]
}
path "secret/metadata/scaleway/registry" {
  capabilities = ["list", "read"]
}
path "secret/metadata/*" {
  capabilities = ["list"]
}
path "auth/token/create" {
  capabilities = ["update"]
}