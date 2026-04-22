pipeline {
    agent {
        label "agent_1"
    }
    environment {
        SCW_REGION = "fr-par"
        BUCKET_NAME = "tf-backend-04596"
    }

    stages {
        stage('Bootstrap Backend') {
            steps {
                withVault(configuration: [
                    disableChildPoliciesOverride: false, 
                    vaultCredentialId: 'Vault_jenkins_terraform', 
                    vaultUrl: 'http://vault:8200' // Assure-toi que Vault est UNSEALED
                ], vaultSecrets: [
                    [path: 'secret/scaleway/access', engineVersion: 2, secretValues: [
                        [envVar: 'SCW_ACCESS_KEY', vaultKey: 'access_key'],
                        [envVar: 'SCW_SECRET_KEY', vaultKey: 'secret_key'],
                        [envVar: 'SCW_PROJECT_ID', vaultKey: 'project_id']
                    ]]
                ]) {
                    script {
                        sh '''
                            # On passe les variables Jenkins au Shell proprement
                            export REGION="$SCW_REGION"
                            export BUCKET="$BUCKET_NAME"
                            export SCW_DEFAULT_PROJECT_ID="$SCW_PROJECT_ID"
                            
                            echo "--- Création du bucket S3 : $BUCKET ---"
                            scw object bucket create name="$BUCKET" region="$REGION" acl=private || true
                            
                            echo "--- Activation du versioning ---"
                            # Utilisation de la clé secrète récupérée de Vault
                            curl -X PUT "https://s3.${REGION}.scw.cloud/${BUCKET}?versioning" \
                                -H "Authorization: Bearer $SCW_SECRET_KEY" \
                                -d '<VersioningConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/"><Status>Enabled</Status></VersioningConfiguration>'
                        '''
                    }
                }
                
                // Génération du fichier TF (Hors du bloc sh pour utiliser l'interpolation Groovy)
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
""".stripIndent()
            }
        }        
        stage('Archive Artifacts') {
            steps {
                archiveArtifacts artifacts: 'backend_config.tf', fingerprint: true
            }
        }
    }
}