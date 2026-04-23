# Scaleway and image registry connection
path "secret/data/scaleway/jenkins_pull" {
  capabilities = ["read"]
}
path "secret/metadata/scaleway/jenkins_pull" {
  capabilities = ["list", "read"]
}

# backend connection
path "secret/data/scaleway/pg_conn_str" {
  capabilities = ["read"]
}
path "secret/metadata/scaleway/pg_conn_str" {
  capabilities = ["list", "read"]
}



path "secret/metadata/*" {
  capabilities = ["list"]
}