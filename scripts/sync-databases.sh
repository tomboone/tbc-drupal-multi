#!/bin/bash

# Database sync script for tbc-drupal-multi
# Syncs databases from prod or stage to local environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SITES=("default" "jeannebriggs" "rsstomboone")
SOURCE_ENV=${1:-prod}

if [[ "$SOURCE_ENV" != "prod" && "$SOURCE_ENV" != "stage" ]]; then
    echo -e "${RED}❌ Invalid environment. Use 'prod' or 'stage'${NC}"
    echo "Usage: $0 [prod|stage]"
    exit 1
fi

echo -e "${YELLOW}🔄 Syncing databases from $SOURCE_ENV to local...${NC}"

for site in "${SITES[@]}"; do
    echo -e "\n${YELLOW}Syncing $site...${NC}"
    
    # Check if local database exists, create if not
    LOCAL_DB="${site}_local"
    if [[ "$site" == "default" ]]; then
        LOCAL_DB="jeanneandtom_local"
    elif [[ "$site" == "jeannebriggs" ]]; then
        LOCAL_DB="jeannebriggs_local"
    elif [[ "$site" == "rsstomboone" ]]; then
        LOCAL_DB="rsstomboone_local"
    fi
    
    # Create local database if it doesn't exist
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`$LOCAL_DB\`" 2>/dev/null || {
        echo -e "${RED}❌ Failed to create local database $LOCAL_DB${NC}"
        echo "Make sure MySQL is running locally and root user has access"
        continue
    }
    
    # Sync database
    if drush sql:sync @$SOURCE_ENV.$site @local.$site -y; then
        echo -e "${GREEN}✅ Synced $site successfully${NC}"
        
        # Run database updates after sync
        echo -e "${YELLOW}Running database updates for $site...${NC}"
        drush --uri=$site updb -y || echo -e "${YELLOW}⚠️  Database updates completed with warnings for $site${NC}"
        
        # Clear cache
        drush --uri=$site cr || echo -e "${YELLOW}⚠️  Cache clear completed with warnings for $site${NC}"
        
    else
        echo -e "${RED}❌ Failed to sync $site${NC}"
    fi
done

echo -e "\n${GREEN}✅ Database sync complete!${NC}"
echo -e "${YELLOW}Don't forget to:${NC}"
echo -e "  • Check your local site settings"
echo -e "  • Update local URLs if needed"
echo -e "  • Test your local sites"