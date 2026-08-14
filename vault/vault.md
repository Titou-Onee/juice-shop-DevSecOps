```bash
secret
├── scaleway 
        ├── access
                ├── terraform   # Scaleway access and informations
                        ├── access_key
                        ├── secret_key
                        ├── organization_id
                        └── project_id
        ├── backend             # Backend for remote state secrets
                ├── db_pass
                ├── db_user
                └── project_id
        ├── jenkins_push        #Terraform provided
                ├── registry
                ├── access_key
                └── secret_key
        ├── jenkins_pull        #Terraform provided
                ├── registry        
                ├── access_key
                ├── secret_key
                ├── namespace_id
                ├── project_id
                ├── organization_id
                └── container_id
        └── pg_conn_str         #Terraform provided
                └── conn_str
├── defectdojo          # Defectdojo api_key   
        └── api_key            

```
# Policies
```bash
policies
        ├── terraform-policy.hcl # Scaleway access, Backend infos, access for jenkins policy creation
        ├── jenkins_pull.hcl # Policy for CI
        ├── jenkins_push.hcl # Policy for CD
```