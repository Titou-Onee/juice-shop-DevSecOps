pipeline{
    agent{
        label "agent_1"
    }
    stages{
        stage('Checkout'){
            steps{
                deleteDir()
                checkout([$class: 'GitSCM', 
                    branches: [[name: '*/master']], 
                    extensions: [[$class: 'CloneOption', depth: 1, shallow: true]], 
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
