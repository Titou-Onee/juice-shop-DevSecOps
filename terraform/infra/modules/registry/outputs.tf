output "push_access_key" {
  value = scaleway_iam_api_key.jenkins_push.access_key
  sensitive = true
}
output "push_secret_key" {
  value = scaleway_iam_api_key.jenkins_push.secret_key
  sensitive = true
}
output "pull_access_key" {
  value = scaleway_iam_api_key.jenkins_pull.access_key
  sensitive = true
}
output "pull_secret_key" {
  value = scaleway_iam_api_key.jenkins_pull.secret_key
  sensitive = true
}
output "registry" {
  value = scaleway_registry_namespace.main.endpoint
}
output "namespace_id" {
  value =scaleway_container_namespace.main.id
}
