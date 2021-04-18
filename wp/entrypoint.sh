#!/bin/bash

CONF_FILE=wp-config.php

if test -f "$CONF_FILE"; then
    echo "$CONF_FILE exists exiting"
    exit 0
fi

# Use wait-for-it to ensyre DB is running
curl https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh > wfi.sh
chmod +x ./wfi.sh
./wfi.sh $WORDPRESS_DB_HOST -t 180
rm -f ./wfi.sh

# Init /var/www/html folder with Wordpress core
wp core download

# Pull default config for docker
curl https://raw.githubusercontent.com/docker-library/wordpress/master/latest/php8.0/apache/wp-config-docker.php > wp-config-docker.php

# Set default Salt's
# Copied from https://github.com/docker-library/wordpress/blob/master/latest/php8.0/apache/docker-entrypoint.sh#L80
awk '
/put your unique phrase here/ {
	cmd = "head -c1m /dev/urandom | sha1sum | cut -d\\  -f1"
	cmd | getline str
	close(cmd)
	gsub("put your unique phrase here", str)
}
{ print }
' "wp-config-docker.php" > $CONF_FILE

# Install and configure site
wp core install --path="/var/www/html" --url="$SITE_URL" --title="$SITE_TITLE" --admin_user="$SITE_ADMIN_USER" --admin_password="$SITE_ADMIN_PASS" --admin_email="$SITE_ADMIN_EMAIL" --skip-email

# Instull plugins
wp plugin install wp-stateless --activate

