terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.2.8"
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
data "vault_kv_secret_v2" "db_access" {
  mount = "secret"
  name  = "scaleway/backend"
}

provider "scaleway" {
  access_key = data.vault_kv_secret_v2.SLW_access.data["access_key"]
  secret_key = data.vault_kv_secret_v2.SLW_access.data["secret_key"]
  region = "fr-par"
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE AN DATABASE INSTANCE TO USE IT AS A TERRAFORM BACKEND
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "scaleway_rdb_database" "database" {
  name        = "terraform-backend"
  instance_id = scaleway_rdb_instance.main.id
}

resource scaleway_rdb_instance main {
  name           = "backend-db"
  node_type      = "db-dev-s"
  engine         = "PostgreSQL-15"
  # Cost saving on this project
  is_ha_cluster  = false
  disable_backup = true
  project_id = data.vault_kv_secret_v2.SLW_access.data["project_id"]
  user_name      = data.vault_kv_secret_v2.db_access.data["db_user"]
  password       = data.vault_kv_secret_v2.db_access.data["db_pass"]
  tags           = ["terraform-backend1"]
}

locals {
  pg_conn_str = "postgres://${data.vault_kv_secret_v2.db_access.data["db_user"]}:${data.vault_kv_secret_v2.db_access.data["db_pass"]}@${scaleway_rdb_instance.main.load_balancer[0].ip}:${scaleway_rdb_instance.main.load_balancer[0].port}/terraform-backend?sslmode=require"
}

resource "vault_kv_secret_v2" "pg_conn" {
  mount = "secret"
  name  = "scaleway/pg_conn_str"

  data_json = jsonencode({
    conn_str = local.pg_conn_str
  })
}

resource "scaleway_rdb_privilege" "main" {
  instance_id   = scaleway_rdb_instance.main.id
  database_name = scaleway_rdb_database.database.name
  user_name     = data.vault_kv_secret_v2.db_access.data["db_user"]
  permission    = "all"
}