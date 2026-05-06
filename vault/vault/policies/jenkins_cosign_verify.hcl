# Public key
path "transit/keys/cosign/*" {
  capabilities = ["read"]
}
path "transit/keys/cosign/*" {
  capabilities = ["read"]
}

# Vault verification
path "transit/verify/cosign" {
  capabilities = ["update"]
}
path "transit/verify/cosign/*" {
  capabilities = ["update"]
}