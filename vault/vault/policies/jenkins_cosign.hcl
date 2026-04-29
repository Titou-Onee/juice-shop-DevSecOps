## KV Secrets Access (Si besoin de lire des métadonnées)
path "secret/data/jenkins/*" {
  capabilities = ["read"]
}

## Cosign Transit Engine Access
# Autorise la lecture des métadonnées de la clé
path "transit/keys/cosign" {
  capabilities = ["read", "list"]
}

# Autorise les opérations de signature
# Note : Cosign utilise l'endpoint /sign/
path "transit/sign/cosign" {
  capabilities = ["update"]
}

path "transit/sign/cosign/*" {
  capabilities = ["update"]
}

# Autorise les opérations de vérification
path "transit/verify/cosign" {
  capabilities = ["update"]
}

path "transit/verify/cosign/*" {
  capabilities = ["update"]
}

# CRITICAL : Correction du chemin d'export de la clé publique
# Vault utilise /public-key/ et non /signing-key/
path "transit/export/public-key/cosign" {
  capabilities = ["read"]
}

# Autorise le listing du moteur transit
path "transit/keys" {
  capabilities = ["list"]
}