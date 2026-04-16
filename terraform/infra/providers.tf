terraform {
  required_providers {
    vault = {
        source = "hashicorp/vault"
        version = "~> 4.0"
    }
  }
}

provider "vault" {
    address = var.Vault_address

    auth_login{
        path = "auth/approle/login"

        parameters = {
          role_id = var.role_id
          secret_id = var.secret_id
        }
    }


  
}