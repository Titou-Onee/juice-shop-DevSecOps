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
    skip_tls_verify = true

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
  name  = "scaleway/access"
}

provider "scaleway" {
  access_key = data.vault_kv_secret_v2.SLW_access.data["access_key"]
  secret_key = var.SLW_secret_key.SLW_access.data["secret_key"]
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE AN DATABASE INSTANCE TO USE IT AS A TERRAFORM BACKEND
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# data "vault_kv_secret_v2" "db_backend" {
#   mount = "secret"
#   name  = "scaleway/db_backend"
# }

# resource "scaleway_rdb_database" "database" {
#   name        = "main-database"
#   instance_id = scaleway_rdb_instance.main.id
# }

# resource scaleway_rdb_instance main {
#   name           = "backend_db"
#   node_type      = "db_dev_s"
#   engine         = "PostgreSQL-11"
#   is_ha_cluster  = false
#   disable_backup = true
#   user_name      = data.vault_kv_secret_v2.db_backend.data["db_user"]
#   password       = data.vault_kv_secret_v2.db_backend.data["db_pass"]
#   tags           = ["terraform-backend1"]
# }

# output "pg_conn_str" {
#   value     = "postgres://${data.vault_kv_secret_v2.db_backend.data["db_user"]}:${data.vault_kv_secret_v2.db_backend.data["db_pass"]}@localhost:5432/terraform_backend?sslmode=disable"
#   sensitive = true
# }