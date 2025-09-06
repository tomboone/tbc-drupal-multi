#!/bin/bash

# Script to check if Drupal configuration has been exported
# Used with pre-commit framework - Docker-aware

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SITES=("default" "jeannebriggs.com" "rss.tomboone.com")

echo -e "${YELLOW}🔍 Checking Drupal configuration export...${NC}"

# Check if we're in a Drupal project
if [ ! -f "web/index.php" ] || [ ! -f "composer.json" ]; then
    echo -e "${RED}❌ Not a Drupal project root${NC}"
    exit 1
fi

# Determine if we're running in Docker or have docker-compose
DRUSH_CMD="drush"
if [ -f "docker-compose.yml" ] && command -v docker-compose &> /dev/null; then
    # Check if containers are running
    if docker-compose ps | grep -q "Up"; then
        DRUSH_CMD="docker-compose exec -T web drush"
        echo -e "${YELLOW}🐳 Using Docker container for Drush commands${NC}"
    else
        echo -e "${YELLOW}⚠️  Docker containers not running, using local Drush${NC}"
    fi
elif command -v docker &> /dev/null && docker ps | grep -q drupal; then
    # Look for a running container with 'drupal' in the name
    CONTAINER=$(docker ps --filter "name=drupal" --format "{{.Names}}" | head -1)
    if [ -n "$CONTAINER" ]; then
        DRUSH_CMD="docker exec -i $CONTAINER drush"
        echo -e "${YELLOW}🐳 Using Docker container: $CONTAINER${NC}"
    fi
fi

failed=0

for site in "${SITES[@]}"; do
    echo -e "Checking site: ${YELLOW}$site${NC}"

    # Skip if site doesn't exist yet
    if [ ! -d "web/sites/$site" ]; then
        echo -e "${YELLOW}⚠️  Site $site not found, skipping${NC}"
        continue
    fi

    # Check if config directory exists
    config_dir="config/$site"
    if [ ! -d "$config_dir" ]; then
        echo -e "${RED}❌ Config directory $config_dir not found for $site${NC}"
        echo -e "${YELLOW}Run: $DRUSH_CMD --uri=$site.local config:export${NC}"
        failed=1
        continue
    fi

    # Check if config directory has files
    if [ -z "$(ls -A $config_dir 2>/dev/null)" ]; then
        echo -e "${RED}❌ Config directory $config_dir is empty for $site${NC}"
        echo -e "${YELLOW}Run: $DRUSH_CMD --uri=$site.local config:export${NC}"
        failed=1
        continue
    fi

    # Basic check: ensure core.extension.yml exists
    if [ ! -f "$config_dir/core.extension.yml" ]; then
        echo -e "${RED}❌ core.extension.yml missing in $config_dir${NC}"
        echo -e "${YELLOW}Run: $DRUSH_CMD --uri=$site.local config:export${NC}"
        failed=1
        continue
    fi

    echo -e "${GREEN}✅ Config appears exported for $site${NC}"
done

if [ $failed -eq 1 ]; then
    echo -e "\n${RED}❌ Configuration export issues detected${NC}"
    echo -e "${YELLOW}Please export configuration for all sites before committing${NC}"
    echo -e "${YELLOW}Use: $DRUSH_CMD --uri=SITENAME.local config:export${NC}"
    exit 1
fi

echo -e "\n${GREEN}✅ All configurations appear to be exported${NC}"
exit 0
