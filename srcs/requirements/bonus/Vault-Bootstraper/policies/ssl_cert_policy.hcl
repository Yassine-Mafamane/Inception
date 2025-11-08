
# This allows services token to be used only to request generating a TLS certificate from vault server

path "pki/issue/42_24H_role" {
  capabilities = ["create", "update"]
  required_parameters = ["common_name"]
}
