terraform {
  backend "pg" {}
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.73.0"
    }
    vault = {
        source = "hashicorp/vault"
        version = "~> 4.0"
    }
  }
}

provider "vault" {
    address = var.vault_address
    skip_tls_verify = true # Certificat is self-signed on this project

    auth_login{
        path = "auth/approle/login"

        parameters = {
          role_id = var.vault_role_id
          secret_id = var.vault_secret_id
        }
    }
}

data "vault_kv_secret_v2" "SLW_access" {
  mount = "secret"
  name  = "scaleway/access/terraform"
}

data "vault_kv_secret_v2" "pg_conn_str" {
  mount = "secret"
  name  = "scaleway/pg_conn_str"
}
provider "scaleway" {
  access_key = data.vault_kv_secret_v2.SLW_access.data["access_key"]
  secret_key = data.vault_kv_secret_v2.SLW_access.data["secret_key"]
  region = "fr-par"
}

resource "scaleway_registry_namespace" "main" {
  name = "jenkins-registry"
  is_public = false
  project_id = data.vault_kv_secret_v2.SLW_access.data["project_id"]
}

resource "scaleway_container_namespace" "main" {
  name = "production-ns"
  description = "Namespace for serverless containers deployment"
  project_id = data.vault_kv_secret_v2.SLW_access.data["project_id"]
}

resource "scaleway_iam_application" "jenkins_push" {
  name = "jenkins-registry-push"
  organization_id = data.vault_kv_secret_v2.SLW_access.data["organization_id"]
}

resource "scaleway_iam_application" "jenkins_pull" {
  name = "jenkins-registry-pull"
  organization_id = data.vault_kv_secret_v2.SLW_access.data["organization_id"]
}

resource "time_rotating" "rotate_after_a_year" {
  rotation_years = 1
}

resource "scaleway_iam_api_key" "jenkins_push" {
  application_id = scaleway_iam_application.jenkins_push.id
  description    = "Jenkins push key"
  expires_at     = time_rotating.rotate_after_a_year.rotation_rfc3339
}

resource "scaleway_iam_api_key" "jenkins_pull" {
  application_id = scaleway_iam_application.jenkins_pull.id
  description    = "Jenkins pull key"
  expires_at     = time_rotating.rotate_after_a_year.rotation_rfc3339
}

# Policy push — accès write au registry
resource "scaleway_iam_policy" "registry_push" {
  name           = "registry-push-policy"
  application_id = scaleway_iam_application.jenkins_push.id
  organization_id = data.vault_kv_secret_v2.SLW_access.data["organization_id"]

  rule {
    project_ids          = [data.vault_kv_secret_v2.SLW_access.data["project_id"]]
    permission_set_names = ["ContainerRegistryFullAccess"]
  }
}

# Policy pull — accès read only au registry
resource "scaleway_iam_policy" "registry_pull" {
  name           = "registry-pull-policy"
  application_id = scaleway_iam_application.jenkins_pull.id
  organization_id = data.vault_kv_secret_v2.SLW_access.data["organization_id"]

  rule {
    project_ids          = [data.vault_kv_secret_v2.SLW_access.data["project_id"]]
    permission_set_names = ["ContainerRegistryReadOnly"]
  }
}

# Stocke les clés dans Vault automatiquement
# resource "vault_kv_secret_v2" "jenkins_push" {
#   mount = "secret"
#   name  = "scaleway/jenkins_push"

#   data_json = jsonencode({
#     registry_username = scaleway_iam_api_key.jenkins_push.access_key
#     registry_password = scaleway_iam_api_key.jenkins_push.secret_key
#     registry = scaleway_registry_namespace.main.endpoint
#   })
# }

# resource "vault_kv_secret_v2" "jenkins_pull" {
#   mount = "secret"
#   name  = "scaleway/jenkins_pull"

#   data_json = jsonencode({
#     registry_username = scaleway_iam_api_key.jenkins_pull.access_key
#     registry_password = scaleway_iam_api_key.jenkins_pull.secret_key
#     registry = scaleway_registry_namespace.main.endpoint
#   })
# }