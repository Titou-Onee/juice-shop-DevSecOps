## CI steps :
- **Github fork** - done
- **Jenkins Local Setup** - done
- **Jenkins pipeline with github** - done
- **semgrep & trivy scan** - done
- **DefectDojo Local Setup** - done
- DefectDojo Jenkins integration
- SBOM creation with syft
- Signature with cosign
- Certification of provenance

## Vault steps :
- Vault local Setup
- Vault Jenkins integration
  
## Deploy steps :
- Signature check
- OWASP ZAP DAST
- Scaleway IaC for VM and image registry
- automatic deployment
- Ops security


# Infra
docker-compose up -d
// launch django-DefectDojo
terraform apply
