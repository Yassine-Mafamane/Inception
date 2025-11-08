#!/bin/sh

set -e

chmod 644 /etc/nginx/ssl

export VAULT_ADDR="http://$VAULT_SERVER_NAME:$VAULT_PORT"

# ============================================
# STEP 1: Authenticate with Vault using AppRole
# ============================================

# Build JSON payload with role_id and secret_id for AppRole authentication
jq -n	\
		--rawfile role_id /var/vault-creds/tls_role_id.txt \
		--rawfile secret_id /var/vault-creds/nginx_secret_id.txt \
		'{"role_id": $role_id, "secret_id": $secret_id}' > /tmp/data.json

# Authenticate with Vault and extract the client token
curl	--silent -X POST \
		--data @/tmp/data.json \
		$VAULT_ADDR/v1/auth/approle/login | \
		jq -r '.auth.client_token' > /tmp/vault_client_token.txt


# ============================================
# STEP 2: Request SSL Certificate from Vault PKI
# ============================================

# Generate SSL certificate for ymafaman.42.fr (24-hour validity)
curl	--silent -X POST \
		-H "X-Vault-Token: $(cat /tmp/vault_client_token.txt)" \
		-H "Content-Type: application/json" \
		-d '{"common_name":"ymafaman.42.fr"}' \
		$VAULT_ADDR/v1/pki/issue/42_24H_role > /tmp/pki_response_data.json

rm -rf	/tmp/vault_client_token.txt

# ============================================
# STEP 3: Extract and Save SSL Certificates
# ============================================

cat /tmp/pki_response_data.json | jq -r '.data.ca_chain' > /etc/nginx/ssl/ca_chain.crt

cat /tmp/pki_response_data.json | jq -r '.data.certificate' > /etc/nginx/ssl/ymafaman.42.fr.crt

cat /tmp/pki_response_data.json | jq -r '.data.private_key' > /etc/nginx/ssl/ymafaman.42.fr.key

# Create fullchain certificate (server cert + CA chain) for nginx
cat /etc/nginx/ssl/ymafaman.42.fr.crt /etc/nginx/ssl/ca_chain.crt > /etc/nginx/ssl/fullchain.pem

rm -rf /tmp/pki_response_data.json

chmod 644 /etc/nginx/ssl/*.crt
chmod 644 /etc/nginx/ssl/*.key

# ============================================
# STEP 4: Start Nginx
# ============================================

exec nginx -g 'daemon off;'