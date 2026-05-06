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

provider "scaleway" {
  access_key = data.vault_kv_secret_v2.SLW_access.data["access_key"]
  secret_key = data.vault_kv_secret_v2.SLW_access.data["secret_key"]
  region = "fr-par"
}