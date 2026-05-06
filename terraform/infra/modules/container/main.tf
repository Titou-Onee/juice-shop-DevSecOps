terraform {
  required_providers {
    scaleway = {
      source = "scaleway/scaleway"
    }
  }
}
resource "scaleway_container" "app" {
  name = "my-app"
  namespace_id = var.namespace_id
  registry_image = var.image

  privacy = "public"
  protocol = "http1"
  port           = 8080
  cpu_limit      = 1024
  memory_limit   = 2048
  min_scale      = 0
  max_scale      = 2
  deploy         = true
}

data "vault_kv_secret_v2" "existing_pull" {
  mount = "secret"
  name  = "scaleway/jenkins_pull"
}
