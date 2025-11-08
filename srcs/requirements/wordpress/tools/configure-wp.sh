#! /bin/sh

set -e

# Configure Vault server address from environment variables
export VAULT_ADDR="http://$VAULT_SERVER_NAME:$VAULT_PORT"

function extract_vault_token {
	# Build AppRole authentication payload from credential files
	jq -n	\
			--rawfile role_id /var/vault-creds/db_admin_role_id.txt \
			--rawfile secret_id /var/vault-creds/db_admin_secret_id.txt \
			'{"role_id": $role_id, "secret_id": $secret_id}' > /tmp/data.json

	# Authenticate with Vault and extract client token
	curl	--silent -X POST --data @/tmp/data.json $VAULT_ADDR/v1/auth/approle/login \
			| jq -r '.auth.client_token' > /tmp/vault_client_token.txt
}

# ============================================
# Configure Database Connection with Dynamic Credentials
# ============================================
function	configure_db_connection {

	# Allow PHP-FPM to accept connections from any interface (required for Docker networking)
	sed -i 's/^listen = 127.0.0.1:9000/listen = 0.0.0.0:9000/' /etc/php83/php-fpm.d/www.conf
	
	# re-extract vault token even if we might have done it before to allow database creds rotation when restarting container after 24H (creds ttl)
	extract_vault_token

	# Fetch temporary database credentials from Vault
	curl	--silent -H "X-Vault-Token: $(cat /tmp/vault_client_token.txt)" \
			$VAULT_ADDR/v1/database/creds/wp-db-role > /tmp/database_creds.json

	export DB_USERNAME=$(cat /tmp/database_creds.json | jq -r '.data.username')
	export DB_PASSWORD=$(cat /tmp/database_creds.json | jq -r '.data.password')

	wp config set DB_USER $DB_USERNAME
	wp config set DB_PASSWORD $DB_PASSWORD
}


function	get_admin_creds {
	curl	--silent -H "X-Vault-Token: $(cat /tmp/vault_client_token.txt)" \
			$VAULT_ADDR/v1/kv/wp-admin-creds > /tmp/wp_creds.json
	
	export WP_ADMIN=$(cat /tmp/wp_creds.json | jq -r '.data.username')
	export WP_ADMIN_PW=$(cat /tmp/wp_creds.json | jq -r '.data.password')
	export WP_ADMIN_EMAIL=$(cat /tmp/wp_creds.json | jq -r '.data.email')

	curl	--silent -H "X-Vault-Token: $(cat /tmp/vault_client_token.txt)" \
			$VAULT_ADDR/v1/kv/wp-author-creds > /tmp/wp_creds.json
	
	export WP_AUTHOR=$(cat /tmp/wp_creds.json | jq -r '.data.username')
	export WP_AUTHOR_PW=$(cat /tmp/wp_creds.json | jq -r '.data.password')
	export WP_AUTHOR_EMAIL=$(cat /tmp/wp_creds.json | jq -r '.data.email')

	rm -f /tmp/wp_creds.json
}

# ============================================
# Install and Configure WordPress
# ============================================
function	install-WordPress {
	if [ ! -f "/var/www/html/wordpress/wp-config.php" ];  then
		
		# ---------------------------------------
        # FIRST-TIME SETUP
        # ---------------------------------------

		echo "Installing WordPress"

		php -d memory_limit=512M /bin/wp core download --path=/var/www/html/wordpress

		cp wp-config-sample.php wp-config.php

		wp config set DB_NAME $DB_NAME
		wp config set DB_HOST mariadb:3306
		wp config set WP_REDIS_HOST redis
		wp config set WP_REDIS_PORT 6379
		wp config set WP_CACHE_KEY_SALT ymafaman:wp

		extract_vault_token

		configure_db_connection

		get_admin_creds

		wp	core install --url=ymafaman.42.fr --title=ymafaman.42.fr \
		--admin_user=$WP_ADMIN --admin_email=$WP_ADMIN_EMAIL \
		--admin_password=$WP_ADMIN_PW

		wp	user create $WP_AUTHOR $WP_AUTHOR_EMAIL \
			--user_pass=$WP_AUTHOR_PW \
			--role=author

		wp theme install legacy-news --activate
	
		wp plugin install redis-cache --activate

		wp redis enable

	else
	 	# ---------------------------------------
        # SUBSEQUENT STARTUPS
        # ---------------------------------------
        
        # WordPress already installed - just refresh database credentials
        # (Vault credentials expire after 24 hours, so we refresh on each restart)
		configure_db_connection
	fi
}

install-WordPress

exec php-fpm83 -F