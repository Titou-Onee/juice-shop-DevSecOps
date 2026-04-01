pipeline{
    agent{
        label "agent_1"
    }
    options {
        // Empêche Jenkins de cloner le repo automatiquement au début
        skipDefaultCheckout() 
    }
    stages{
        stage('Hello'){
            steps{
                echo 'running'
            }
        }
        stage('Checkout'){
            steps{
                deleteDir()
                checkout([$class: 'GitSCM', 
                    branches: [[name: '*/master']], 
                    extensions: [
                        [$class: 'CloneOption', 
                            depth: 1,          // Récupère uniquement le dernier commit
                            shallow: true,     // Active le mode superficiel
                            noTags: true,      // SURTOUT : Ne pas télécharger les tags (gain de place énorme)
                            timeout: 30        // Augmente le délai d'attente à 30 min au lieu de 10
                        ]
                    ], 
                    userRemoteConfigs: [[url: 'https://github.com/juice-shop/juice-shop.git']]
                ])
            }
        }
        stage('SAST Scan') {
            steps {
                echo 'Running Semgrep SAST scan ...'

                sh 'semgrep --config p/ci --json > semgrep-results.json'

                archiveArtifacts artifacts: 'semgrep-results.json', allowEmptyArchive: true

                script {
                    def semgrepResults = readFile('semgrep-results.json')
                    echo "Semgrep Scan Results: ${semgrepResults}"
                }
            }
        }
    }
}
