pipeline{
    agent{
        label "agent_1"
    }
    options {
        skipDefaultCheckout()
    }
    parameters{
        string(name: 'IMAGE_DIGEST', defaultValue: 'sha256:840649e6bfd3ac2ec1d7ed3e09b0fb61e3575deb1323f8803b64f902793fcf07', description: 'Image digest')
        string(name: 'IMAGE_TAG', defaultValue: 'null-240', description: 'Image tag')
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

                            VAULT_TOKEN=$(curl -sf \
                                --request POST \
                                --cacert /usr/local/share/ca-certificates/my-internal-ca.crt \
                                --data "{\\"role_id\\":\\"${ROLE_ID}\\",\\"secret_id\\":\\"${SECRET_ID}\\"}" \
                                "${VAULT_ADDR}/v1/auth/approle/login" \
                                | jq -r '.auth.client_token')
                            
                            export VAULT_TOKEN
                            export TRANSIT_SECRET_ENGINE_PATH="transit"

                            cosign verify \
                                --key "$COSIGN_KEY" \
                                --allow-insecure-registry=false \
                                --insecure-ignore-tlog \
                                "$IMAGE_FULL_REF@$IMAGE_DIGEST"

                            sleep 2
                            cosign verify-attestation \
                                --key "$COSIGN_KEY" \
                                --insecure-ignore-tlog \
                                --type cyclonedx \
                                "${IMAGE_FULL_REF}@${IMAGE_DIGEST}"
                            
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
                                [envVar: 'SCW_NS_ID',      vaultKey: 'namespace_id']
                                ]]]) {
                                sh '''
                                    export SCW_ACCESS_KEY="${REGISTRY_USER}"
                                    export SCW_SECRET_KEY="${REGISTRY_PASS}"
                                    export SCW_DEFAULT_PROJECT_ID="${SCW_PROJECT_ID}"
                                    export SCW_DEFAULT_REGION="fr-par"
                                    scw container container update name="${IMAGE_NAME}" \
                                        namespace-id="${SCW_NS_ID}" \
                                        image="${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}@${IMAGE_DIGEST}" \
                                        redeploy=true
                                '''
                        }
                }
            }
    }
}