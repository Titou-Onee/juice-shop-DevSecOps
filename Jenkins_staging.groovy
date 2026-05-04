pipeline{
    agent{
        label "agent_1"
    }
    options {
        skipDefaultCheckout()
    }
    parameters{
        string(name: 'IMAGE_DIGEST', defaultValue: 'sha256:324d6f1fef351bf561291a5d2f298ea90b0d7eb86aff2b331787bfdc9895706d', description: 'Image digest')
        string(name: 'IMAGE_TAG', defaultValue: 'null-242', description: 'Image tag')
        string(name: 'IMAGE_NAME', defaultValue: 'vulnerable-app',description:  'Image name')
        string(name: 'NAMESPACE', defaultValue: 'main', description: 'deployment namespace')
        string(name: 'REGISTRY', defaultValue: 'rg.fr-par.scw.cloud/jenkins-registry', description: 'Registry')
    }
    environment{

        VAULT_URL= "https://vault:8200"
        COSIGN_EXPERIMENTAL = "0"
        COSIGN_KEY = "hashivault://cosign"
    }   
    stages{   
        stage('Verify Signature') {
                steps {
                    withVault(configuration: [disableChildPoliciesOverride: false, engineVersion: 2, timeout: 60, vaultCredentialId: 'Jenkins_pull', vaultUrl: 'https://vault:8200'], 
                    vaultSecrets: [
                        [path: 'secret/cosign/keys_verify', secretValues: [[envVar: 'ROLE_ID', vaultKey: 'role_id'], [envVar: 'SECRET_ID', vaultKey: 'secret_id']]]
                    ]) {                
                        sh ''' 
                            export VAULT_ADDR="$VAULT_URL"
                            export IMAGE_FULL_REF="${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}"
                            set +x
                            VAULT_TOKEN=$(curl -sf \
                                --request POST \
                                --cacert /usr/local/share/ca-certificates/my-internal-ca.crt \
                                --data "{\\"role_id\\":\\"${ROLE_ID}\\",\\"secret_id\\":\\"${SECRET_ID}\\"}" \
                                "${VAULT_ADDR}/v1/auth/approle/login" \
                                | jq -r '.auth.client_token')
                            set -x
                            export VAULT_TOKEN
                            export TRANSIT_SECRET_ENGINE_PATH="transit"

                            cosign verify \
                                --key "$COSIGN_KEY" \
                                --allow-insecure-registry=false \
                                --insecure-ignore-tlog \
                                "$IMAGE_FULL_REF:$IMAGE_DIGEST"

                            sleep 5
                            # cosign verify-attestation \
                            #     --key "$COSIGN_KEY" \
                            #     --insecure-ignore-tlog \
                            #     --type cyclonedx \
                            #     "${IMAGE_FULL_REF}:${IMAGE_DIGEST}"
                            
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
                                [envVar: 'REGISTRY_USER', vaultKey: 'registry_username'],
                                [envVar: 'REGISTRY_PASS', vaultKey: 'registry_password'],
                                [envVar: 'SCW_PROJECT_ID', vaultKey: 'project_id'],
                                [envVar: 'SCW_NS_ID',      vaultKey: 'namespace_id'],
                                [envVar: 'ORGANIZATION_ID',vaultKey: 'organization_id'],
                                [envVar: 'CONTAINER_ID', vaultKey: 'container_id']
                                ]]]) {
                                sh '''
                                    export SCW_ACCESS_KEY="${REGISTRY_USER}"
                                    export SCW_SECRET_KEY="${REGISTRY_PASS}"
                                    export SCW_DEFAULT_PROJECT_ID="${SCW_PROJECT_ID}"
                                    export SCW_DEFAULT_REGION="fr-par"
                                    export SCW_DEFAULT_ORGANIZATION_ID="${ORGANIZATION_ID}"
                                    
                                    scw container container update "${CONTAINER_ID}" \
                                        registry-image="${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:${IMAGE_DIGEST}"

                                    echo "Container deployed"

                                '''
                        }
                }
            }
            stage('OWASP ZAP Scan') {
                steps {
                    script {
                        env.CONTAINER_IP = sh(script : "scw container container get <CONTAINER_ID> --format='json' | jq -r '.domain_name'", returnStdout: true).trim()
                        echo "L'application est déployée sur : https://env.CONTAINER_IP"
                        sh "docker run --rm -v \$(pwd):/zap/wrk/:rw -t ghcr.io/zaproxy/zaproxy:w2026-04-27@31d55a4e1b2d8bf400b195781eee8de83b1bad8d7e3bdacb4b34b4bd8e0867f8 zap-baseline.py \
                            -t $CONTAINER_IP:8080 \
                            -J zap-report.json || true"
                    }
                    archiveArtifacts artifacts: 'zap-report.json', allowEmptyArchive: true
                }
            }
    }
}