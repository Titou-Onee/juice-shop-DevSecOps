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
                grypeScan autoInstall: true, repName: 'grypeReport_${JOB_NAME}_${BUILD_NUMBER}.txt', scanDest: 'sbom:sbom.json'
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
                        artifact: 'grypeReport_${JOB_NAME}_${BUILD_NUMBER}.txt',
                        scanType: 'Anchore Grype',
                        productName: 'Juice-shop-Jenkins',
                        engagementName: 'Jenkins'
                    )
            }
        }        
    }
}
