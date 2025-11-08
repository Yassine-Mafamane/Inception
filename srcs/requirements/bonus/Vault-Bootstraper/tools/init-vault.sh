#! /bin/sh

set -e

#############################################################
# 		VAULT INITIALIZATION AND CONFIGURATION SCRIPT
#############################################################
# This script bootstraps a HashiCorp Vault instance by:
# 	1. Initializing Vault (first run) or unsealing it (subsequent runs)
# 	2. Configuring AppRole authentication for service-to-service auth
# 	3. Setting up PKI engine for TLS certificate management
# 	4. Configuring database engine for dynamic credential generation
# 	5. Storing secrets and credentials in shared volumes for services
#
# Services configured:
# - NGINX: Obtains TLS certificates from PKI engine
# - WordPress: Retrieves dynamic database credentials
#############################################################

export VAULT_ADDR="http://$VAULT_SERVER_NAME:$VAULT_PORT"

# Unseal Vault using Shamir's Secret Sharing (3 of 5 keys required)
# Vault seals automatically on shutdown to protect data at rest.
unseal_vault() {
	for i in 1 2 3; do
		export UNSEAL_KEY_${i}=$(cat /var/vault-creds/unseal_key_${i}.txt)
		vault operator unseal $(eval echo \$UNSEAL_KEY_${i})
	done
}

export INITIALIZED=$(vault status | grep Initialized | awk '{print $2}')

if [ "$INITIALIZED" = "true" ]; then
	echo "Vault is already initialized!"

	export SEALED=$(vault status | grep Sealed | awk '{print $2}')
	if [ "$SEALED" = "true" ]; then
		unseal_vault
	fi
	exit 0
fi

vault operator init > /tmp/vaul_init_response.txt

for i in 1 2 3 4 5; do
	cat /tmp/vaul_init_response.txt \
		| grep "Unseal Key ${i}" \
		| awk '{print $4}' \
		> /var/vault-creds/unseal_key_${i}.txt
done

cat     /tmp/vaul_init_response.txt \
		| grep "Initial Root Token" \
		| awk '{print $4}' \
		> /var/vault-creds/vault_root_token.txt

export VAULT_ROOT_TOKEN=$(cat /var/vault-creds/vault_root_token.txt)

unseal_vault

vault login $VAULT_ROOT_TOKEN

#############################################################
#   APPROLE AUTHENTICATION SETUP
#   Configures AppRole auth method and creates roles for:
#       - NGINX: TLS certificate provisioning
#       - WordPress: Database credential access
#############################################################

vault auth enable approle

vault policy write ssl_cert_policy /var/vault-policies/ssl_cert_policy.hcl

# AppRole for services to obtain TLS certificates
vault write auth/approle/role/ssl_role \
	  secret_id_ttl=0 \
	  token_num_uses=1 \
	  token_ttl=10m \
	  token_max_ttl=10m \
	  token_type=default \
	  policies="ssl_cert_policy"

# Generate and store AppRole credentials for NGINX service authentication
vault   read -field="role_id" auth/approle/role/ssl_role/role-id \
		> /var/vault-creds/nginx/tls_role_id.txt

vault   write -f -field="secret_id" auth/approle/role/ssl_role/secret-id \
		> /var/vault-creds/nginx/nginx_secret_id.txt

# AppRole for database credential provisioning

vault policy write wp-db-policy /var/vault-policies/wp-db-policy.hcl

# 24H because if the token expires before that the database credentials are going to be revoked.
vault write auth/approle/role/db_admin_role \
	  secret_id_ttl=24h \
	  token_ttl=24h \
	  token_max_ttl=24h \
	  token_type=default \
	  policies="wp-db-policy"

vault	read -field="role_id" auth/approle/role/db_admin_role/role-id \
		> /var/vault-creds/wordpress/db_admin_role_id.txt

vault	write -f -field="secret_id" auth/approle/role/db_admin_role/secret-id \
		> /var/vault-creds/wordpress/db_admin_secret_id.txt

#############################################################
# 	PKI ENGINE - CERTIFICATE AUTHORITY SETUP
# 	Configures certificate generation for 42.fr and subdomains
#	with 24-hour validity periods
#############################################################

vault secrets enable pki

# Set maximum TTL for PKI engine to allow 1-year root certificate generation
vault secrets tune -max-lease-ttl=8766h pki

vault write pki/root/generate/internal common_name=42.fr ttl=8760h > /tmp/ca.crt

vault   write pki/config/urls \
		issuing_certificates="http://127.0.0.1:8200/v1/pki/ca" \
		crl_distribution_points="http://127.0.0.1:8200/v1/pki/crl"

# PKI role for issuing short-lived certificates to *.42.fr subdomains
vault   write pki/roles/42_24H_role \
		allowed_domains=42.fr \
		allow_subdomains=true \
		ttl=24h \
		max_ttl=24h

#############################################################
# 	DATABASE SECRETS ENGINE SETUP
# 	Configures Vault to dynamically generate database credentials:
# 		- Connects to MariaDB/WordPress database
# 		- Creates roles for full-access and read-only users
# 		- Rotates root password for enhanced security
#############################################################

vault secrets enable database

# Connect Vault to MariaDB database engine
vault	write database/config/wp-database \
		plugin_name=mysql-database-plugin \
		connection_url="{{username}}:{{password}}@tcp(mariadb:3306)/" \
		allowed_roles="wp-db-role, db-readonly" \
		username="root" \
		password=$MARIADB_ROOT_PW

# Rotate root password.
#	! NOTE : After this step only vault will know the root pw and no one else!
vault	write -f database/rotate-root/wp-database

# Database role for full-access credentials (WordPress admin)
vault	write database/roles/wp-db-role \
		db_name=wp-database \
		default_ttl="24h" \
		max_ttl="24h" \
		creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}'; \
			GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '{{name}}'@'%';"

vault	write database/roles/db-readonly \
		db_name=wp-database \
		default_ttl="24h" \
		max_ttl="24h" \
		creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}'; \
			GRANT SELECT ON ${DB_NAME}.* TO '{{name}}'@'%';"


vault	read  database/creds/db-readonly > /var/vault-creds/Read-only-user-creds.txt

# Enabling  audit logs
vault audit enable file file_path=/var/lib/vault-logs/vault-audit.log

##################################################

vault write sys/policies/password/custom-pw-policy policy=@/var/vault-policies/password-policy.hcl

vault	secrets enable -version=1 kv

vault	kv put kv/wp-admin-creds \
		username=$WP_ADMIN_USERNAME \
		password=$(vault read -field password sys/policies/password/custom-pw-policy/generate) \
		email=$WP_ADMIN_EMAIL

vault	kv put kv/wp-author-creds \
		username=$WP_AUTHOR_USERNAME \
		password=$(vault read -field password sys/policies/password/custom-pw-policy/generate) \
		email=$WP_AUTHOR_EMAIL

##################################################


vault auth enable userpass

vault write auth/userpass/users/"$USERPASS_USER_NAME" \
    password="$USERPASS_PASSWORD" \
    policies=wp-db-policy

# At this point, approle credentials have been writen in shared volumes with other services that need them. PKI engine has been enabled and services are ready to start and request secrets they need from vault.
