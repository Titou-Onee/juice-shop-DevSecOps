pipeline{
    agent{
        label "agent_1"
    }

    options {
        skipDefaultCheckout()
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20')) 
    }
    environment{
        GRYPE_DB_CACHE_DIR = "/opt/grype-db"
        NAMESPACE = "main"
        IMAGE_NAME = "vulnerable-app"
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
                script{
                    env.GIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.IMAGE_TAG = "${env.GIT_SHORT}-${env.BUILD_NUMBER}"
                }
            }
        }
        stage('Install dependancies'){
            steps{
                sh 'npm install --package-lock-only || true'
            }
        }
        stage('Scan SAST & SCA & Linting & repo scan') {
            parallel{
                stage('Semgrep') {
                    steps{
                    echo 'Running Semgrep SAST scan ...'
                    sh '/opt/semgrep-venv/bin/semgrep --config auto . --json --output semgrep-results.json || true'

                    archiveArtifacts artifacts: '**/semgrep-results.json', allowEmptyArchive: true
                    }
                }
                stage('trivy'){
                    steps{
                    sh 'trivy fs --format json --output trivy-results.json --severity HIGH,CRITICAL --exit-code 1 . || true'
                    archiveArtifacts artifacts: '**/trivy-results.json', allowEmptyArchive: true
                    }
                }
                stage('Hadolint (Docker Lint)') {
                    steps {
                        echo 'Running Dockerfile Linting...'
                        sh 'docker run --rm -i hadolint/hadolint hadolint --format json < Dockerfile > hadolint-results.json || true'                        
                        archiveArtifacts artifacts: 'hadolint-results.json', allowEmptyArchive: true
                    }
                }
                stage('TruffleHog'){
                    steps{
                        script{
                            sh '''
                                docker run --rm \
                                -v ${WORKSPACE}:/pwd \
                                trufflesecurity/trufflehog:3.95.2@sha256:49d1c4fbbc580aac487ac7cb0517bb085826bd352d7578d62bb4c0c6b7205075 \
                                git file:///pwd --only-verified --fail || true
                            '''
                        }
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
        stage('SBOM creation with Syft'){
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
                secretValues: [[envVar: 'ACCESS_KEY', 
                vaultKey: 'access_key'], 
                [envVar: 'SECRET_KEY', vaultKey: 'secret_key']]]]) {                
                sh '''
                    printf '%s' "$SECRET_KEY" | docker login "$REGISTRY" -u "$ACCESS_KEY" --password-stdin
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
                        
                        
                        VAULT_TOKEN="$VAULT_TOKEN" TRANSIT_SECRET_ENGINE_PATH="transit" \
                        cosign sign \
                            --key "$COSIGN_KEY" \
                            --tlog-upload=false \
                            --annotations "git-commit=$GIT_COMMIT" \
                            --annotations "build-number=$BUILD_NUMBER" \
                            --annotations "pipeline-stage=sign" \
                            --yes \
                            "$IMAGE_FULL_REF@$IMAGE_DIGEST"

                        VAULT_TOKEN="$VAULT_TOKEN" TRANSIT_SECRET_ENGINE_PATH="transit" \
                        cosign attest \
                            --key "$COSIGN_KEY" \
                            --tlog-upload=false \
                            --type cyclonedx \
                            --predicate sbom.json \
                            "$IMAGE_FULL_REF@$IMAGE_DIGEST"
                        
                        curl -sf -H "X-Vault-Token: $VAULT_TOKEN" \
                            --cacert /usr/local/share/ca-certificates/my-internal-ca.crt \
                            -X POST "$VAULT_ADDR/v1/auth/token/revoke-self" || echo "WARN : revocation of Vault token failed"
                        '''
                }
            } 
        }       
        stage('Upload result to DefectDojo') {
            steps {
                // On utilise le bloc script pour pouvoir définir du code Groovy pur (fonctions, variables)
                script {
                withVault(configuration: [disableChildPoliciesOverride: false, engineVersion: 2, timeout: 60, vaultCredentialId: 'Jenkins_push', vaultUrl: 'https://vault:8200'], vaultSecrets: [[
                    path: 'secret/defectdojo', secretValues: [[envVar: 'API_KEY', vaultKey: 'api_key']]]]) {
                        def uploadToDojo = { fileName, scanType ->
                            env.dojoUrl = "http://host.docker.internal:8080/api/v2/import-scan/"
                            env.product = "Juice-shop-Jenkins"
                            env.engagement = "Jenkins"
                            env.fileName = fileName
                            env.scanType = scanType
                            sh '''
                                curl -X POST "${dojoUrl}" \
                                -H "Authorization: Token ${API_KEY}" \
                                -F "product_name=${product}" \
                                -F "engagement_name=${engagement}" \
                                -F "scan_type=${scanType}" \
                                -F "file=@${fileName}" \
                                -F "close_old_findings=true" \
                                -F "push_to_jira=false" \
                                -F "active=true" \
                                -F "verified=true" \
                                -F "version=${BUILD_NUMBER}"
                            '''
                        }

                        // Appels de la fonction
                        uploadToDojo("semgrep-results.json", "Semgrep JSON Report")
                        uploadToDojo("grype-report.json", "Anchore Grype")
                        uploadToDojo("hadolint-results.json", "Hadolint Dockerfile check") 
                    }
                }
            }
        }
        stage('Wait for Registry'){
            steps{
                sh 'sleep 30'
            }
        }
        stage('Promote to Stagging?') {
            steps {
                script {
                    def userInput = input(
                        id: 'confirm',
                        message: "Deploy the image to Stagging ?",
                        parameters: [
                            booleanParam(defaultValue: true, description: 'Confirm the deplyment', name: 'CONFIRM_DEPLOY')
                        ]
                    )

                    if (userInput) {
                        echo "Deploy pipeline launch..."
                        build job: 'staging_pipeline', 
                              wait: false,
                              parameters: [
                                    string(name: 'IMAGE_DIGEST', value: env.IMAGE_DIGEST),
                                    string(name: 'IMAGE_TAG', value: env.IMAGE_TAG),
                                    string(name: 'IMAGE_NAME', value: env.IMAGE_NAME),
                                    string(name: 'REGISTRY', value: env.REGISTRY)
                              ]
                    } else {
                        echo "Deployment canceled"
                    }
                }
            }
        }
    }
    post {
        always {
            sh 'docker logout || true'
            sh 'rm -f sbom.json || true'
            echo "${IMAGE_DIGEST};${IMAGE_TAG}; ${IMAGE_NAME} ; ${REGISTRY}"
        }
        failure {
            echo "Pipeline failed - no signed image or verified"
        }
    }
}