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
        stage('SAST Scan') {
            steps {
                sh '$VENV/bin/pip install semgrep'
                echo 'Running Semgrep SAST scan ...'
                sh '$VENV/bin/python3 semgrep --config p/ci --json > semgrep-results.json'

                archiveArtifacts artifacts: 'semgrep-results.json', allowEmptyArchive: true

                script {
                    def semgrepResults = readFile('semgrep-results.json')
                    echo "Semgrep Scan Results: ${semgrepResults}"
                }
            }
        }
    }
}
