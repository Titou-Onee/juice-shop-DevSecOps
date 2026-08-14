# TERRAFORM Infrastructure

```bash
backend
├── main.tf
├── variables.tf
└── terraform.tfvars
infra
├── main.tf
├── providers.tf
├── variables.tf
├── terraform.tfvars.tf
└── modules
        ├── container
        └── registry
```

- This project deploys a container registry with a serverless container
- The "Backend" repertory deploys a backend database for terraform remote state

Terraform infra depends of Vault, please set-up vault and fill terraform.tfvars for infra/ and backend/
Please read the terraform part in the main README.md 

Run :
```bash
cd backend
terraform init
terraform apply --auto-approve
```

Terraform will write de PG_CONN_STR of the backend in Vault path : secret/scaleway/pg_conn_str

```bash
cd ../infra
export PG_CONN_STR="postgres://user_example:pass_example@host:port/terraform-backend?sslmode=require"
terraform init
terraform apply --auto-approve
```