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
        IMAGE_TAG  = "${BUILD_NUMBER}"
    }
    stages{
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
        stage('Scan SAST & SCA') {
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
                    sh 'trivy fs --format json --output trivy-results.json --severity HIGH,CRITICAL --exit-code 1 . || true'
                    archiveArtifacts artifacts: '**/trivy-results.json', allowEmptyArchive: true
                    }
                }
            }
        }
        stage('Docker build'){
            steps{
                withVault(configuration: [disableChildPoliciesOverride: false, engineVersion: 2, timeout: 60, vaultCredentialId: 'Jenkins_push', vaultUrl: 'https://vault:8200'], vaultSecrets: [[path: 'secret/scaleway/jenkins_push', secretValues: [[envVar: 'REGISTRY', vaultKey: 'registry']]]]) {    
                    sh 'docker build -t ${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG} \
                                -t ${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:latest .'
                }
            }   
        }
        stage('SBOM creation with Snyk'){
            steps{
                sh 'syft build -o json > sbom.json'
            }
        }
        stage('Grype scan'){
            steps{
                sh 'grype db update'

                sh '''
                    grype sbom:sbom.json --output json --file grype-report.json
                '''    
                archiveArtifacts artifacts: '**/grype-report.json', allowEmptyArchive: true
            }
        }
        stage('Docker push on Scaleway image registry'){
            steps{
                withVault(configuration: [disableChildPoliciesOverride: false, engineVersion: 2, timeout: 60, vaultCredentialId: 'Jenkins_push', vaultUrl: 'https://vault:8200'], vaultSecrets: [[path: 'secret/scaleway/jenkins_push', secretValues: [[envVar: 'REGISTRY_USER', vaultKey: 'registry_username'], [envVar: 'REGISTRY_PASS', vaultKey: 'registry_password'], [envVar: 'REGISTRY', vaultKey: 'registry']]]]) {                
                sh """
                    echo "${REGISTRY_PASS}" | docker login ${REGISTRY} -u ${REGISTRY_USER} --password-stdin
                    docker push ${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:latest
                """
                }
            }
            post {
                success {
                    provenanceRecorder artifactFilter: 'build/libs/**.jar', targetDirectory: 'build/slsa'
                }
            }
        }

        stage('Upload result to DefectDojo'){
            steps{
                withVault(configuration: [disableChildPoliciesOverride: false, engineVersion: 2, timeout: 60, vaultCredentialId: 'Jenkins_push', vaultUrl: 'https://vault:8200'], vaultSecrets: [[path: 'secret/defectdojo', secretValues: [[envVar: 'API_KEY', vaultKey: 'api_key']]]]) {                
                    sh '''
                    curl -X POST "http://host.docker.internal:8080/api/v2/import-scan/" \
                    -H "Authorization: Token $API_KEY" \
                    -F "file=@trivy-results.json" \
                    -F "scan_type=Trivy Scan" \
                    -F "product_name=Juice-shop-Jenkins" \
                    -F "engagement_name=Jenkins"
                    '''

                    sh '''
                    curl -X POST "http://host.docker.internal:8080/api/v2/import-scan/" \
                    -H "Authorization: Token $API_KEY" \
                    -F "file=@semgrep-results.json" \
                    -F "scan_type=Semgrep JSON Report" \
                    -F "product_name=Juice-shop-Jenkins" \
                    -F "engagement_name=Jenkins"
                    '''
                    
                    sh '''
                    curl -X POST "http://host.docker.internal:8080/api/v2/import-scan/" \
                    -H "Authorization: Token $API_KEY" \
                    -F "file=@grype-report.json" \
                    -F "scan_type=Anchore Grype" \
                    -F "product_name=Juice-shop-Jenkins" \
                    -F "engagement_name=Jenkins"
                    '''
                }
            }
        }        
    }
}
