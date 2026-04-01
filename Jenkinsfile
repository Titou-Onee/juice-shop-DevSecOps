pipeline{
    agent{
        label "agent_1"
    }
    stages{
        stage('Checkout'){
            steps{
                echo 'Cloning the repository'
                git branch: 'master', url: 'https://github.com/Titou-Onee/juice-shop-DevSecOps.git'
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
