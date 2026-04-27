pipeline{
    agent{
        label "agent_1"
    }

    options {
        skipDefaultCheckout()
    }
    environment{
        VENV = "${WORKSPACE}/jenkins_python"
        GRYPE_DB_CACHE_DIR = "/opt/grype-db"
        NAMESPACE = "main"
        IMAGE_NAME = "vulnerable-app"
        IMAGE_TAG  = "${GIT_COMMIT}-${BUILD_NUMBER}"
        VAULT_URL= "https://vault:8200"
        COSIGN_EXPERIMENTAL = "0"
        COSIGN_KEY = "hashivault://cosign"
    }
    stages{
        stage('Initialize Environment') {
            steps {
                script {
                    withVault(configuration: [engineVersion: 2, vaultCredentialId: 'Jenkins_push', vaultUrl: 'https://vault:8200'], 
                              vaultSecrets: [[path: 'secret/scaleway/jenkins_push', 
                                              secretValues: [[envVar: 'TEMP_REGISTRY', vaultKey: 'registry']]]]) {

                        env.REGISTRY = env.TEMP_REGISTRY
                    }
                }
            }
        }
        stage('Checkout'){
            steps{
                deleteDir()
                checkout([$class: 'GitSCM', 
                    branches: [[name: '*/master']], 
                    extensions: [
                        [$class: 'CloneOption', 
                            depth: 1,
                            shallow: true,
                            noTags: true,
                            timeout: 30
                        ]
                    ], 
                    userRemoteConfigs: [[url: 'https://github.com/cr0hn/vulnerable-node.git']]
                ])
            }
        }
        stage('Setup venv'){
            steps{
                sh 'python3 -m venv $VENV'
            }
        }
        stage('Scan SAST & SCA & Linting') {
            parallel{
                stage('Semgrep') {
                    steps{
                    sh "$VENV/bin/pip install semgrep"
                    echo 'Running Semgrep SAST scan ...'
                    sh '$VENV/bin/semgrep scan --config p/ci --json --error > semgrep-results.json || true'

                    archiveArtifacts artifacts: '**/semgrep-results.json', allowEmptyArchive: true
                    }
                }
                stage('trivy'){
                    steps{
                    sh 'trivy fs --format json --output trivy-results.json --severity HIGH,CRITICAL --exit-code 1 ./juice-application || true'
                    archiveArtifacts artifacts: '**/trivy-results.json', allowEmptyArchive: true
                    }
                }
                stage('Hadolint (Docker Lint)') {
                    steps {
                        echo 'Running Dockerfile Linting...'
                        sh 'docker run --rm -i hadolint/hadolint < ./juice-application/Dockerfile > hadolint-results.json || true'
                        
                        sh 'docker run --rm -i hadolint/hadolint < ./juice-application/Dockerfile || true'
                        
                        archiveArtifacts artifacts: 'hadolint-results.json', allowEmptyArchive: true
                    }
                }
            }
        }
        stage('Docker build'){
            steps{   
                sh 'docker build -t ${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG} \
                    -t ${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:latest .'
            }   
        }
        stage('SBOM creation with Snyk'){
            steps{
                sh 'syft scan docker:${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG} -o cyclonedx-json=sbom.json'
                archiveArtifacts artifacts: '**/sbom.json', allowEmptyArchive: true
            }
        }
        stage('Image and SBOM scan'){
            parallel{
                stage("Grype scan"){
                    steps{
                        sh 'grype db update'

                        sh '''
                            grype sbom:sbom.json --output json \
                            --file grype-report.json
                        '''    
                        archiveArtifacts artifacts: '**/grype-report.json', allowEmptyArchive: true
                    }
                }
                stage("Trivy image scan"){
                    steps{
                    sh "trivy image --format json --output trivy-image-results.json ${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}"
                    archiveArtifacts 'trivy-image-results.json'
                    }
                }
            }
            
        }
        stage('Docker push on Scaleway image registry'){
            steps{
                withVault(configuration: [disableChildPoliciesOverride: false, engineVersion: 2, timeout: 60, vaultCredentialId: 'Jenkins_push', vaultUrl: 'https://vault:8200'], vaultSecrets: [[
                path: 'secret/scaleway/jenkins_push',
                secretValues: [[envVar: 'REGISTRY_USER', 
                vaultKey: 'registry_username'], 
                [envVar: 'REGISTRY_PASS', vaultKey: 'registry_password']]]]) {                
                sh '''
                    printf '%s' "$REGISTRY_PASS" | docker login "$REGISTRY" -u "$REGISTRY_USER" --password-stdin
                    docker push "$REGISTRY"/"$NAMESPACE"/"$IMAGE_NAME":"$IMAGE_TAG"
                    docker push "$REGISTRY"/"$NAMESPACE"/"$IMAGE_NAME":latest
                '''
                }
            }
        }
        stage('Sign image and attest SBOM'){
            steps {
                withVault(configuration: [disableChildPoliciesOverride: false, engineVersion: 2, timeout: 60, vaultCredentialId: 'Jenkins_push', vaultUrl: 'https://vault:8200'], 
                vaultSecrets: [[path: 'secret/cosign/keys', secretValues: [[envVar: 'ROLE_ID',vaultKey: 'role_id'], [envVar: 'SECRET_ID', vaultKey: 'secret_id']]]]) {                
                    script {
                        def image_ref = "${env.REGISTRY}/${env.NAMESPACE}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"
                        env.IMAGE_DIGEST = sh(script: "crane digest ${image_ref}", returnStdout: true).trim()
                        env.IMAGE_FULL_REF = "${env.REGISTRY}/${env.NAMESPACE}/${env.IMAGE_NAME}"
                    }

                    sh '''
                        export VAULT_ADDR="$VAULT_URL"

                        VAULT_TOKEN=$(curl -sf \
                            --request POST \
                            --cacert /usr/local/share/ca-certificates/my-internal-ca.crt \
                            --data "{\\"role_id\\":\\"${ROLE_ID}\\",\\"secret_id\\":\\"${SECRET_ID}\\"}" \
                            "${VAULT_ADDR}/v1/auth/approle/login" \
                            | jq -r '.auth.client_token')
                        
                        export VAULT_TOKEN
                        export TRANSIT_SECRET_ENGINE_PATH="transit"
                        
                        cosign sign \
                            --key "$COSIGN_KEY" \
                            --tlog-upload=false \
                            --annotations "git-commit=$GIT_COMMIT" \
                            --annotations "build-number=$BUILD_NUMBER" \
                            --annotations "pipeline-stage=sign" \
                            --yes \
                            "$IMAGE_FULL_REF@$IMAGE_DIGEST"

                        cosign attest \
                            --key "$COSIGN_KEY" \
                            --tlog-upload=false \
                            --type cyclonedx \
                            --predicate sbom.json \
                            "$IMAGE_FULL_REF@$IMAGE_DIGEST"
                        
                        curl -sf -H "X-Vault-Token: $VAULT_TOKEN" \
                            --cacert /usr/local/share/ca-certificates/my-internal-ca.crt \
                            -X POST "$VAULT_ADDR/v1/auth/token/revoke-self" || true
                        '''
                }
            }        
        // stage('Upload result to DefectDojo'){
        //     steps{
        //         withVault(configuration: [disableChildPoliciesOverride: false, engineVersion: 2, timeout: 60, vaultCredentialId: 'Jenkins_push', vaultUrl: 'https://vault:8200'], vaultSecrets: [[path: 'secret/defectdojo', secretValues: [[envVar: 'API_KEY', vaultKey: 'api_key']]]]) {                
        //             sh '''
        //             curl -X POST "http://host.docker.internal:8080/api/v2/import-scan/" \
        //             -H "Authorization: Token $API_KEY" \
        //             -F "file=@trivy-results.json" \
        //             -F "scan_type=Trivy Scan" \
        //             -F "product_name=Juice-shop-Jenkins" \
        //             -F "engagement_name=Jenkins"
        //             '''

        //             sh '''
        //             curl -X POST "http://host.docker.internal:8080/api/v2/import-scan/" \
        //             -H "Authorization: Token $API_KEY" \
        //             -F "file=@semgrep-results.json" \
        //             -F "scan_type=Semgrep JSON Report" \
        //             -F "product_name=Juice-shop-Jenkins" \
        //             -F "engagement_name=Jenkins"
        //             '''
                    
        //             sh '''
        //             curl -X POST "http://host.docker.internal:8080/api/v2/import-scan/" \
        //             -H "Authorization: Token $API_KEY" \
        //             -F "file=@grype-report.json" \
        //             -F "scan_type=Anchore Grype" \
        //             -F "product_name=Juice-shop-Jenkins" \
        //             -F "engagement_name=Jenkins"
        //             '''
        //         }
        //     }
        // }
        post {
            always {
                sh 'docker logout || true'
                sh 'rm -f sbom.json || true'
            }
            failure {
                echo "Pipeline failed - no signed image or verified"
            }
        }     
        }
    }
}
