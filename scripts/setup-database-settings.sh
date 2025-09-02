#!/bin/bash

# Script to generate and upload settings.php files with database credentials
# This script gets credentials from Terraform and uploads settings to Azure File Share

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 Database Settings Generator${NC}"
echo "======================================"

# Check if we're in the project root
if [ ! -f "terraform/main.tf" ]; then
    echo -e "${RED}❌ Please run this script from the project root directory${NC}"
    exit 1
fi

# Check prerequisites
echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform not found. Please install Terraform.${NC}"
    exit 1
fi

if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI not found. Please install Azure CLI.${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ jq not found. Please install jq.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

# Get Terraform outputs
echo -e "${YELLOW}📊 Getting database configuration from Terraform...${NC}"
cd terraform

# Check if Terraform is initialized
if [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}⚠️  Terraform not initialized. Running terraform init...${NC}"
    terraform init
fi

# Get database connections
echo -e "${YELLOW}🔍 Extracting database credentials...${NC}"
DB_CONNECTIONS=$(terraform output -json all_database_connections)
MYSQL_HOST=$(terraform output -raw mysql_host)
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name)

cd ..

# Create local settings directory
mkdir -p local-settings
echo -e "${GREEN}📁 Created local-settings directory${NC}"

# Generate settings.php for each site
echo -e "${YELLOW}🏗️  Generating settings.php files...${NC}"

# Extract sites from the production databases
SITES=$(echo "$DB_CONNECTIONS" | jq -r '. | to_entries[] | select(.key | contains("_stage") | not) | .key')

for SITE in $SITES; do
    echo -e "${BLUE}  📝 Generating settings for: $SITE${NC}"
    
    # Get production credentials
    PROD_DB=$(echo "$DB_CONNECTIONS" | jq -r ".[\"$SITE\"].database")
    PROD_USER=$(echo "$DB_CONNECTIONS" | jq -r ".[\"$SITE\"].username") 
    PROD_PASS=$(echo "$DB_CONNECTIONS" | jq -r ".[\"$SITE\"].password")
    PROD_HOST=$(echo "$DB_CONNECTIONS" | jq -r ".[\"$SITE\"].host")
    PROD_PORT=$(echo "$DB_CONNECTIONS" | jq -r ".[\"$SITE\"].port")
    
    # Get staging credentials
    STAGE_DB=$(echo "$DB_CONNECTIONS" | jq -r ".[\"${SITE}_stage\"].database")
    STAGE_USER=$(echo "$DB_CONNECTIONS" | jq -r ".[\"${SITE}_stage\"].username")
    STAGE_PASS=$(echo "$DB_CONNECTIONS" | jq -r ".[\"${SITE}_stage\"].password")
    STAGE_HOST=$(echo "$DB_CONNECTIONS" | jq -r ".[\"${SITE}_stage\"].host")
    STAGE_PORT=$(echo "$DB_CONNECTIONS" | jq -r ".[\"${SITE}_stage\"].port")
    
    # Generate settings.php file
    cat > "local-settings/${SITE}.settings.php" << EOF
<?php

/**
 * Database settings for $SITE
 * Generated automatically from Terraform outputs
 * Environment-aware: switches between production and staging databases
 */

\$env = \$_ENV['DRUPAL_ENV'] ?? 'production';

if (\$env === 'staging') {
  // Staging database configuration
  \$databases['default']['default'] = [
    'database' => '$STAGE_DB',
    'username' => '$STAGE_USER',
    'password' => '$STAGE_PASS',
    'host' => '$STAGE_HOST',
    'port' => '$STAGE_PORT',
    'driver' => 'mysql',
    'prefix' => '',
    'charset' => 'utf8mb4',
    'collation' => 'utf8mb4_unicode_ci',
    'init_commands' => [
      'sql_mode' => "SET sql_mode = 'TRADITIONAL'",
    ],
    'pdo' => [
      \PDO::MYSQL_ATTR_SSL_CA => '/mnt/sites/mysql/azure_combined_ca.pem',
      \PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => FALSE,
    ],
  ];
} else {
  // Production database configuration
  \$databases['default']['default'] = [
    'database' => '$PROD_DB',
    'username' => '$PROD_USER',
    'password' => '$PROD_PASS',
    'host' => '$PROD_HOST',
    'port' => '$PROD_PORT',
    'driver' => 'mysql',
    'prefix' => '',
    'charset' => 'utf8mb4',
    'collation' => 'utf8mb4_unicode_ci',
    'init_commands' => [
      'sql_mode' => "SET sql_mode = 'TRADITIONAL'",
    ],
    'pdo' => [
      \PDO::MYSQL_ATTR_SSL_CA => '/mnt/sites/mysql/azure_combined_ca.pem',
      \PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => FALSE,
    ],
  ];
}

// Trusted host settings
\$settings['trusted_host_patterns'] = [
  '^$SITE\.com$',
  '^.*\.azurewebsites\.net$',
];

// File paths
\$settings['file_public_path'] = 'sites/$SITE/files';
\$settings['file_private_path'] = '/mnt/sites/$SITE/private';

// Config sync directory
\$settings['config_sync_directory'] = '../../../config/$SITE';

// Hash salt (you should set this manually for security)
// \$settings['hash_salt'] = 'your-unique-hash-salt-here';

EOF

    echo -e "${GREEN}    ✅ Generated local-settings/${SITE}.settings.php${NC}"
done

echo ""
echo -e "${GREEN}🎉 All settings.php files generated successfully!${NC}"
echo ""

# Show summary
echo -e "${BLUE}📋 Summary:${NC}"
echo "  MySQL Host: $MYSQL_HOST"
echo "  Storage Account: $STORAGE_ACCOUNT"
echo "  Generated settings for: $(echo $SITES | tr '\n' ' ')"
echo ""

# Ask if user wants to upload to Azure File Share
echo -e "${YELLOW}📤 Upload settings.php files to Azure File Share? (y/n)${NC}"
read -r UPLOAD_CHOICE

if [[ $UPLOAD_CHOICE =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}🚀 Uploading to Azure File Share...${NC}"
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        echo -e "${YELLOW}⚠️  Not logged into Azure. Please run: az login${NC}"
        exit 1
    fi
    
    for SITE in $SITES; do
        echo -e "${BLUE}  📤 Uploading settings for: $SITE${NC}"
        
        # Upload to Azure File Share
        az storage file upload \
            --account-name "$STORAGE_ACCOUNT" \
            --share-name sites \
            --source "local-settings/${SITE}.settings.php" \
            --path "$SITE/settings.php" \
            --auth-mode login \
            --overwrite \
            && echo -e "${GREEN}    ✅ Uploaded successfully${NC}" \
            || echo -e "${RED}    ❌ Upload failed${NC}"
    done
    
    echo ""
    echo -e "${GREEN}🎉 Upload completed!${NC}"
    echo -e "${BLUE}🌐 Your sites should now have database connectivity${NC}"
    
else
    echo -e "${YELLOW}📁 Settings files are ready in local-settings/ directory${NC}"
    echo -e "${BLUE}   To upload later, run:${NC}"
    for SITE in $SITES; do
        echo "   az storage file upload --account-name $STORAGE_ACCOUNT --share-name sites --source local-settings/${SITE}.settings.php --path $SITE/settings.php --auth-mode login"
    done
fi

echo ""
echo -e "${GREEN}✅ Database settings setup complete!${NC}"