#!/bin/bash
wp core install --path="/var/www/html" --url="$SITE_URL" --title="$SITE_TITLE" --admin_user="$SITE_ADMIN_USER" --admin_password="$SITE_ADMIN_PASS" --admin_email="$SITE_ADMIN_EMAIL" --skip-email
wp plugin install wp-stateless --activate
