pipeline{
    agent{
        label "agent_1"
    }
    options {
        skipDefaultCheckout()
        timeout(time: 45, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20')) 
    }
    parameters{
        string(name: 'IMAGE_DIGEST', defaultValue: 'sha256:f06845c2a3c3e09017f33c4b1f2d0f4e20c7d4c965fdf88e5c8af62c4d7bc373', description: 'Image digest')
        string(name: 'IMAGE_TAG', defaultValue: 'null-262', description: 'Image tag')
        string(name: 'IMAGE_NAME', defaultValue: 'vulnerable-app',description:  'Image name')
        string(name: 'NAMESPACE', defaultValue: 'main', description: 'deployment namespace')
        string(name: 'REGISTRY', defaultValue: 'rg.fr-par.scw.cloud/jenkins-registry', description: 'registry endpoint')
    }
    environment{

        VAULT_URL= "https://vault:8200"
        COSIGN_EXPERIMENTAL = "0"
        COSIGN_KEY = "hashivault://cosign"
    }   
    stages{
        // stage('Initialize Environment') {
        //     steps {
        //         script {
        //             withVault(configuration: [engineVersion: 2, vaultCredentialId: 'Jenkins_pull', vaultUrl: 'https://vault:8200'], 
        //                       vaultSecrets: [[path: 'secret/scaleway/jenkins_push', 
        //                                       secretValues: [[envVar: 'TEMP_REGISTRY', vaultKey: 'registry']]]]) {

        //                 env.REGISTRY = env.TEMP_REGISTRY
        //             }
        //         }
        //     }
        // }   
        stage('Verify Signature') {
                steps {
                    withVault(configuration: [disableChildPoliciesOverride: false, engineVersion: 2, timeout: 60, vaultCredentialId: 'Jenkins_pull', vaultUrl: 'https://vault:8200'], 
                    vaultSecrets: [
                        [path: 'secret/cosign/keys_verify', secretValues: [[envVar: 'ROLE_ID', vaultKey: 'role_id'], [envVar: 'SECRET_ID', vaultKey: 'secret_id']]]
                    ]) {                
                        sh ''' 
                            export VAULT_ADDR="$VAULT_URL"
                            export IMAGE_FULL_REF="${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}"
                            VAULT_TOKEN=$(curl -sf \
                                --request POST \
                                --cacert /usr/local/share/ca-certificates/my-internal-ca.crt \
                                --data "{\\"role_id\\":\\"${ROLE_ID}\\",\\"secret_id\\":\\"${SECRET_ID}\\"}" \
                                "${VAULT_ADDR}/v1/auth/approle/login" \
                                | jq -r '.auth.client_token')

                            VAULT_TOKEN="$VAULT_TOKEN" TRANSIT_SECRET_ENGINE_PATH="transit" \
                            cosign verify \
                                --key "$COSIGN_KEY" \
                                --allow-insecure-registry=false \
                                --insecure-ignore-tlog \
                                "$IMAGE_FULL_REF@$IMAGE_DIGEST"

                            sleep 5
                            # VAULT_TOKEN="$VAULT_TOKEN" TRANSIT_SECRET_ENGINE_PATH="transit" \
                            # cosign verify-attestation \
                            #     --key "$COSIGN_KEY" \
                            #     --insecure-ignore-tlog \
                            #     --type cyclonedx \
                            #     "${IMAGE_FULL_REF}@${IMAGE_DIGEST}"
                            
                            curl -sf -H "X-Vault-Token: $VAULT_TOKEN" \
                                --cacert /usr/local/share/ca-certificates/my-internal-ca.crt \
                                -X POST "$VAULT_ADDR/v1/auth/token/revoke-self" || true
                        '''
                    }

                }
        }
        stage('Deploy container image'){
            steps{
                withVault(configuration: [engineVersion: 2, vaultCredentialId: 'Jenkins_pull', vaultUrl: "${env.VAULT_URL}"], 
                        vaultSecrets: [[path: 'secret/scaleway/jenkins_pull', 
                                secretValues: [
                                [envVar: 'ACCESS_KEY', vaultKey: 'access_key'],
                                [envVar: 'SECRET_KEY', vaultKey: 'secret_key'],
                                [envVar: 'SCW_PROJECT_ID', vaultKey: 'project_id'],
                                [envVar: 'SCW_NS_ID',      vaultKey: 'namespace_id'],
                                [envVar: 'ORGANIZATION_ID',vaultKey: 'organization_id'],
                                [envVar: 'CONTAINER_ID', vaultKey: 'container_id']
                                ]]]) {
                                script{
                                sh '''

                                    SCW_ACCESS_KEY="${ACCESS_KEY}" \
                                    SCW_SECRET_KEY="${SECRET_KEY}" \
                                    SCW_DEFAULT_PROJECT_ID="${SCW_PROJECT_ID}" \
                                    SCW_DEFAULT_REGION="fr-par" \
                                    SCW_DEFAULT_ORGANIZATION_ID="${ORGANIZATION_ID}" \
                                    scw container container update "${CONTAINER_ID}" \
                                        registry-image="${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}@${IMAGE_DIGEST}"

                                    '''
                                    echo "${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}@${IMAGE_DIGEST}"
                                    env.CONTAINER_DOMAIN = sh(
                                    script: '''
                                        SCW_ACCESS_KEY="${ACCESS_KEY}" \
                                        SCW_SECRET_KEY="${SECRET_KEY}" \
                                        SCW_DEFAULT_PROJECT_ID="${SCW_PROJECT_ID}" \
                                        SCW_DEFAULT_REGION="fr-par" \
                                        SCW_DEFAULT_ORGANIZATION_ID="${ORGANIZATION_ID}" \
                                        scw container container get "${CONTAINER_ID}" -o json | jq -r '.domain_name'
                                    ''',
                                    returnStdout: true
                                ).trim()
                                }
                        }
                }
            }
            stage('Wait for Container') {
                steps {
                    script {
                        echo "Waiting for app to respond at https://${CONTAINER_DOMAIN}..."
                        
                        sh '''
                            # Tentative de connexion pendant 5 minutes maximum (30 * 10s)
                            count=0
                            until $(curl --output /dev/null --silent --head --fail https://${CONTAINER_DOMAIN}); do
                                printf '.'
                                sleep 10
                                count=$((count+1))
                                if [ $count -eq 30 ]; then
                                echo "Timeout: Container is not responding after 5 minutes"
                                exit 1
                                fi
                            done
                            echo "Container is UP and Ready!"
                        '''
                    }
                }
            }
            stage('OWASP ZAP Scan') {
                steps {
                        script {
                            echo "L'application est déployée sur : https://${env.CONTAINER_DOMAIN}"
                            sh '''
                                mkdir -p ${WORKSPACE}/zap-reports
                                chown 1000:1000 ${WORKSPACE}/zap-reports
                                
                                docker run --rm \
                                --name zap-scan \
                                --user 1000:1000 \
                                --network host \
                                -v ${WORKSPACE}/zap-reports:/zap/wrk:rw \
                                ghcr.io/zaproxy/zaproxy:2.17.0@sha256:707fc6b9fd8327ba48bb7b49d0c5732c179b045dab9c99f8b95410627dff4a00 \
                                zap-baseline.py \
                                    -t https://${CONTAINER_DOMAIN} \
                                    -J zap-report.json \
                                    -x zap-report.xml
                            '''
                                    }
                        archiveArtifacts artifacts: 'zap-reports/zap-report.json', allowEmptyArchive: true
                        archiveArtifacts artifacts: 'zap-reports/zap-report.xml', allowEmptyArchive: true
                }
            }
            stage('Upload result to DefectDojo') {
            steps {
                // On utilise le bloc script pour pouvoir définir du code Groovy pur (fonctions, variables)
                script {
                withVault(configuration: [disableChildPoliciesOverride: false, engineVersion: 2, timeout: 60, vaultCredentialId: 'Jenkins_pull', vaultUrl: 'https://vault:8200'], vaultSecrets: [[
                    path: 'secret/defectdojo', secretValues: [[envVar: 'API_KEY', vaultKey: 'api_key']]]]) {
                        def uploadToDojo = { fileName, scanType ->
                            env.dojoUrl = "http://host.docker.internal:8080/api/v2/reimport-scan/"
                            env.product = "Juice-shop-Jenkins"
                            env.engagement = "Jenkins"
                            env.fileName = fileName
                            env.scan_type = scanType
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
                        uploadToDojo("zap-report.xml", "ZAP scan") 
                    }
                }
            }
        }
    }
    post {
        always {
            sh 'docker logout || true'
            sh 'rm -f sbom.json || true'
            echo " ${IMAGE_DIGEST} ; ${IMAGE_TAG} ; ${IMAGE_NAME} ; ${REGISTRY}"
        }
        failure {
            echo "Pipeline failed - no signed image or verified"
        }
    }
}