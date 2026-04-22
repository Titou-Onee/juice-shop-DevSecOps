pipeline {
    agent{
        label "agent_1"
    }
    environment {
        SCW_REGION = "fr-par"
        BUCKET_NAME = "tf-backend-04596"
    }

    stages {
        stage('Fetch Secrets') {
            steps {
                withVault(configuration: [
                disableChildPoliciesOverride: false, 
                vaultCredentialId: 'Vault_jenkins_terraform', 
                vaultUrl: 'http://vault:8200'
            ], vaultSecrets: [
                [path: 'secret/scaleway/access', engineVersion: 2, secretValues: [
                    [envVar: 'SCW_ACCESS_KEY', vaultKey: 'access_key'],
                    [envVar: 'SCW_SECRET_KEY', vaultKey: 'secret_key'],
                    [envVar: 'SCW_PROJECT_ID', vaultKey: 'project_id']
                ]]
            ]) {
                script {
                    sh '''
                        # On définit la variable par défaut pour la CLI scw
                        export SCW_DEFAULT_PROJECT_ID="$SCW_PROJECT_ID"
                        
                        echo "Vérification/Création du bucket S3..."
                        # On utilise les variables d'environnement injectées par withVault
                        scw object bucket create name="$BUCKET_NAME" acl=private || true
                        
                        echo "Activation du versioning..."
                        curl -X PUT "https://s3.${SCW_REGION}.scw.cloud/${BUCKET_NAME}?versioning" \
                            -H "Authorization: Bearer $SCW_SECRET_KEY" \
                            -d '<VersioningConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/"><Status>Enabled</Status></VersioningConfiguration>'
                    '''
                }
            }
                        
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
        stage('Archive Artifacts') {
            steps {
                archiveArtifacts artifacts: 'backend_config.tf', fingerprint: true
            }
        }
    }
}