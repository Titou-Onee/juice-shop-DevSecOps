module "registry" {
    source = "./modules/registry"
    organization_id = data.vault_kv_secret_v2.SLW_access.data["organization_id"]
    project_id = data.vault_kv_secret_v2.SLW_access.data["project_id"]
}
module "container" {
    source = "./modules/container"
    registry_endpoint =  module.registry.registry
    namespace_id = module.registry.namespace_id
    image = "alpine:latest"
}


# Stocke les clés dans Vault automatiquement
resource "vault_kv_secret_v2" "jenkins_push" {
  mount = "secret"
  name  = "scaleway/jenkins_push"

  data_json = jsonencode({
    access_key = module.registry.push_access_key
    secret_key =  module.registry.push_secret_key
    registry = module.registry.registry
  })
}

resource "vault_kv_secret_v2" "jenkins_pull" {
  mount = "secret"
  name  = "scaleway/jenkins_pull"

  data_json = jsonencode({
    access_key = module.registry.pull_access_key
    secret_key =  module.registry.pull_secret_key
    namespace_id = module.registry.namespace_id
    registry = module.registry.registry

    project_id = data.vault_kv_secret_v2.SLW_access.data["project_id"]
    organization_id = data.vault_kv_secret_v2.SLW_access.data["organization_id"]

    container_id = module.container.container_id
  })
}