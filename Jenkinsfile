pipeline{
    agent{
        label "agent_1"
    }
    options {
        // Empêche Jenkins de cloner le repo automatiquement au début
        skipDefaultCheckout() 
    }
    environment{
        VENV = "${WORKSPACE}/jenkins_python"
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
                    userRemoteConfigs: [[url: 'https://github.com/juice-shop/juice-shop.git']]
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

                    archiveArtifacts artifacts: 'semgrep-results.json', allowEmptyArchive: true
                    }
                }
                stage('trivy'){
                    steps{
                    sh 'trivy fs --format json --output trivy-results.json --severity HIGH,CRITICAL --exit-code 1 . || true'
                    archiveArtifacts artifacts: 'trivy-results.json', allowEmptyArchive: true
                    }
                }
            }
        }
        stage('Upload result to DefectDojo'){
            steps{
                    defectDojoPublisher(
                        artifact: 'trivy-results.json',
                        scanType: 'Trivy Scan',
                        productName: 'Juice-shop-Jenkins',
                        engagementName: 'Jenkins',
                    )
                    
                    // Upload du deuxième rapport (SAST)
                    defectDojoPublisher(
                        artifact: 'semgrep-results.json',
                        scanType: 'Semgrep JSON Report',
                        productName: 'Juice-shop-Jenkins',
                        engagementName: 'Jenkins', // Même nom pour regrouper !
                    )
            }
        }

    }
}
