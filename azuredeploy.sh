#!/bin/bash
set -e

# The Azure App Service platform can be slow to mount the code share.
# This loop waits up to 60 seconds for the custom nginx config to be available.
for i in {1..12}; do
    if [ -f "/home/site/wwwroot/nginx/azure/default" ]; then
        echo "Custom Nginx config found."
        break
    fi
    echo "Waiting for code mount... (Attempt $i/12)"
    sleep 5
done

if [ ! -f "/home/site/wwwroot/nginx/azure/default" ]; then
    echo "Error: Custom Nginx config not found after 60 seconds. Exiting."
    exit 1
fi

# Copy the custom Nginx vhost configuration, overwriting the default.
echo "Copying custom Nginx configuration to /etc/nginx/sites-enabled/default"
cp /home/site/wwwroot/nginx/azure/default /etc/nginx/sites-enabled/default

# Start the default services (PHP-FPM in the background, Nginx in the foreground)
echo "Starting default services (PHP-FPM and Nginx)..."
php-fpm -D
nginx -g 'daemon off;'
