#!/bin/bash

# Script to run drush deploy on Azure App Service
# Usage: ./run-drush-deploy.sh <webapp-name> <slot-name> <sites-json>

set -e

WEBAPP_NAME="$1"
SLOT_NAME="$2"
SITES_JSON="$3"

if [ -z "$WEBAPP_NAME" ] || [ -z "$SLOT_NAME" ] || [ -z "$SITES_JSON" ]; then
    echo "Usage: $0 <webapp-name> <slot-name> <sites-json>"
    exit 1
fi

echo "🚀 Running Drush deploy on $WEBAPP_NAME ($SLOT_NAME slot)..."

# Parse sites from JSON
SITES=$(echo "$SITES_JSON" | jq -r 'keys[]')

for site in $SITES; do
    echo "📦 Running drush deploy for site: $site"
    
    # Create the drush deploy command
    COMMAND="cd /home/site/wwwroot && drush --uri=$site.local deploy -v --no-interaction"
    
    # Run command on the slot
    az webapp ssh \
        --name "$WEBAPP_NAME" \
        --slot "$SLOT_NAME" \
        --command "$COMMAND" \
        --timeout 300 \
        || {
            echo "⚠️  Warning: Drush deploy failed for $site"
            echo "Continuing with other sites..."
        }
    
    echo "✅ Drush deploy completed for $site"
done

echo "🎉 All drush deploy commands completed!"