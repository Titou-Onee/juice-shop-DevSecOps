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
        stage('Test Vault'){
            steps{
                withVault(configuration: [disableChildPoliciesOverride: false, timeout: 60, vaultCredentialId: 'b5b8de51-c813-4f5d-bd21-d2cdc99d8cb1', vaultUrl: 'https://vault:8200'], vaultSecrets: [[path: '/v1/secret/data/terraform/first-secret', secretValues: [[envVar: 'MY_SECRET', vaultKey: 'tokent']]]]) {
                sh 'echo "hello : $MY_SECRET"'
            }
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
                sh 'docker build -t build .'
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
        // stage('Docker push on Scaleway image registry'){

        // }
//         post {
//             success {
//                 provenanceRecorder artifactFilter: 'build/libs/**.jar', targetDirectory: 'build/slsa'
//             }
// }
        stage('Upload result to DefectDojo'){
            steps{
                    defectDojoPublisher(
                        artifact: 'trivy-results.json',
                        scanType: 'Trivy Scan',
                        productName: 'Juice-shop-Jenkins',
                        engagementName: 'Jenkins'
                    )
                    
                    // Upload du deuxième rapport (SAST)
                    defectDojoPublisher(
                        artifact: 'semgrep-results.json',
                        scanType: 'Semgrep JSON Report',
                        productName: 'Juice-shop-Jenkins',
                        engagementName: 'Jenkins'
                    )
                    defectDojoPublisher(
                        artifact: 'grype-report.json',
                        scanType: 'Anchore Grype',
                        productName: 'Juice-shop-Jenkins',
                        engagementName: 'Jenkins'
                    )
            }
        }        
    }
}
