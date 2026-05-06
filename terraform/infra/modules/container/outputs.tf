output "container_id" {
  value = element(split("/", scaleway_container.app.id), 1)
}