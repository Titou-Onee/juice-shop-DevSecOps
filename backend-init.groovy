pipeline {
    agent any
    
    environment {
        // Configuration de la CLI Scaleway pour le script
        SCW_REGION = "fr-par"
        BUCKET_NAME = "tf-backend-company-unique-id"
    }

    stages {
        stage('Fetch Secrets') {
            steps {
                // On récupère tout d'un coup depuis Vault
                withVault(configuration: [vaultUrl: 'http://vault-container:8200'], vaultSecrets: [
                    [path: 'secret/scaleway/access', engineVersion: 2, secretValues: [
                        [envVar: 'SCW_ACCESS_KEY', vaultKey: 'access_key'],
                        [envVar: 'SCW_SECRET_KEY', vaultKey: 'secret_key'],
                        [envVar: 'SCW_PROJECT_ID', vaultKey: 'project_id']
                    ]]
                ]) {
                    script {
                        // 1. Création du Bucket via la CLI Scaleway
                        sh """
                            export SCW_ACCESS_KEY=${SCW_ACCESS_KEY}
                            export SCW_SECRET_KEY=${SCW_SECRET_KEY}
                            export SCW_DEFAULT_PROJECT_ID=${SCW_PROJECT_ID}
                            
                            echo "Vérification/Création du bucket S3..."
                            scw object bucket create name=${BUCKET_NAME} acl=private || true
                            
                            echo "Activation du versioning..."
                            curl -X PUT "https://s3.${SCW_REGION}.scw.cloud/${BUCKET_NAME}?versioning" \
                                 -H "Authorization: Bearer ${SCW_SECRET_KEY}" \
                                 -d '<VersioningConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/"><Status>Enabled</Status></VersioningConfiguration>'
                        """
                        
                        // 2. Génération du fichier backend pour les autres projets
                        writeFile file: 'backend_config.tf', text: """
terraform {
  backend "s3" {
    bucket                      = "${BUCKET_NAME}"
    key                         = "global/terraform.tfstate"
    region                      = "${SCW_REGION}"
    endpoint                    = "https://s3.${SCW_REGION}.scw.cloud"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }
}
"""
                    }
                }
            }
        }
        
        stage('Archive Artifacts') {
            steps {
                // On archive le fichier généré pour pouvoir le copier 
                // dans les autres projets Terraform si besoin
                archiveArtifacts artifacts: 'backend_config.tf', fingerprint: true
            }
        }
    }
}