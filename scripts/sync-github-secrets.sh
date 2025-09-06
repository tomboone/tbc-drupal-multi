#!/bin/bash

# Script to sync GitHub secrets from Terraform configuration files
# Usage: ./sync-github-secrets.sh <github-workflow-file> [terraform-directory]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check arguments
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo -e "${RED}❌ Usage: $0 <github-workflow-file> [terraform-directory]${NC}"
    echo "Example: $0 .github/workflows/deploy.yml terraform/"
    echo "Example: $0 .github/workflows/deploy.yml (uses current directory)"
    exit 1
fi

WORKFLOW_FILE="$1"
TERRAFORM_DIR="${2:-.}"

# Validate input files
if [ ! -f "$WORKFLOW_FILE" ]; then
    echo -e "${RED}❌ GitHub workflow file not found: $WORKFLOW_FILE${NC}"
    exit 1
fi

if [ ! -d "$TERRAFORM_DIR" ]; then
    echo -e "${RED}❌ Terraform directory not found: $TERRAFORM_DIR${NC}"
    exit 1
fi

TFVARS_FILE="$TERRAFORM_DIR/terraform.tfvars"
BACKEND_FILE="$TERRAFORM_DIR/backend.hcl"

echo -e "${YELLOW}🔄 Syncing GitHub secrets from Terraform configuration...${NC}"
echo -e "${BLUE}📄 Workflow file: $WORKFLOW_FILE${NC}"
echo -e "${BLUE}📁 Terraform directory: $TERRAFORM_DIR${NC}"

# Check if GitHub CLI is installed and authenticated
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed${NC}"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI is not authenticated${NC}"
    echo "Run: gh auth login"
    exit 1
fi

# Arrays to store secrets and missing values
declare -a tf_var_secrets=()
declare -a tf_state_secrets=()
declare -a missing_values=()

echo -e "\n${YELLOW}🔍 Parsing workflow file for secrets...${NC}"

# Extract TF_VAR_ environment variables from workflow file
while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*TF_VAR_([^:]+):[[:space:]]*\$\{\{[[:space:]]*secrets\.([^}[:space:]]+)[[:space:]]*\}\} ]]; then
        tf_var_name="${BASH_REMATCH[1]}"
        secret_name="${BASH_REMATCH[2]}"
        tf_var_secrets+=("$tf_var_name:$secret_name")
        echo -e "  ${GREEN}Found TF_VAR_${tf_var_name} → secrets.${secret_name}${NC}"
    fi
done < "$WORKFLOW_FILE"

# Extract TF_STATE_ secrets from workflow file  
while IFS= read -r line; do
    if [[ "$line" =~ \$\{\{[[:space:]]*secrets\.(TF_STATE_[^}[:space:]]+)[[:space:]]*\}\} ]]; then
        secret_name="${BASH_REMATCH[1]}"
        # Avoid duplicates
        if [[ ! " ${tf_state_secrets[@]} " =~ " ${secret_name} " ]]; then
            tf_state_secrets+=("$secret_name")
            echo -e "  ${GREEN}Found TF_STATE secret: ${secret_name}${NC}"
        fi
    fi
done < "$WORKFLOW_FILE"

if [ ${#tf_var_secrets[@]} -eq 0 ] && [ ${#tf_state_secrets[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No TF_VAR_ or TF_STATE_ secrets found in workflow file${NC}"
    exit 0
fi

# Function to extract value from terraform.tfvars
get_tfvars_value() {
    local var_name="$1"
    local file="$2"
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    # Handle both quoted and unquoted values, with or without spaces
    local value=$(grep -E "^[[:space:]]*${var_name}[[:space:]]*=" "$file" | head -1 | sed -E 's/^[[:space:]]*[^=]*=[[:space:]]*//' | sed -E 's/^"(.*)"$/\1/' | sed -E "s/^'(.*)'$/\1/")
    
    if [ -n "$value" ]; then
        echo "$value"
        return 0
    fi
    return 1
}

# Function to extract value from backend.hcl
get_backend_value() {
    local var_name="$1"
    local file="$2"
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    # Map TF_STATE_XXX to actual backend.hcl key names
    local backend_key=""
    case "$var_name" in
        "TF_STATE_RG")
            backend_key="resource_group_name"
            ;;
        "TF_STATE_SA")
            backend_key="storage_account_name"
            ;;
        "TF_STATE_CONTAINER")
            backend_key="container_name"
            ;;
        "TF_STATE_KEY")
            backend_key="key"
            ;;
        *)
            # Fallback: convert TF_STATE_XXX to lowercase
            backend_key=$(echo "$var_name" | sed 's/^TF_STATE_//' | tr '[:upper:]' '[:lower:]')
            ;;
    esac
    
    # Handle both quoted and unquoted values
    local value=$(grep -E "^[[:space:]]*${backend_key}[[:space:]]*=" "$file" | head -1 | sed -E 's/^[[:space:]]*[^=]*=[[:space:]]*//' | sed -E 's/^"(.*)"$/\1/' | sed -E "s/^'(.*)'$/\1/")
    
    if [ -n "$value" ]; then
        echo "$value"
        return 0
    fi
    return 1
}

echo -e "\n${YELLOW}📝 Processing TF_VAR_ secrets...${NC}"

# Process TF_VAR_ secrets
for secret_pair in "${tf_var_secrets[@]}"; do
    IFS=':' read -r tf_var secret_name <<< "$secret_pair"
    
    echo -e "\n${BLUE}Processing TF_VAR_${tf_var} → ${secret_name}...${NC}"
    
    if value=$(get_tfvars_value "$tf_var" "$TFVARS_FILE"); then
        echo -e "  ${GREEN}✓ Found value in terraform.tfvars${NC}"
        
        # Create/update GitHub secret
        if echo "$value" | gh secret set "$secret_name"; then
            echo -e "  ${GREEN}✅ GitHub secret '${secret_name}' created/updated${NC}"
        else
            echo -e "  ${RED}❌ Failed to create GitHub secret '${secret_name}'${NC}"
        fi
    else
        echo -e "  ${RED}❌ Value not found in terraform.tfvars${NC}"
        missing_values+=("TF_VAR_${tf_var} (for secret ${secret_name}) - expected in terraform.tfvars")
    fi
done

echo -e "\n${YELLOW}🔐 Processing TF_STATE_ secrets...${NC}"

# Process TF_STATE_ secrets
for secret_name in "${tf_state_secrets[@]}"; do
    echo -e "\n${BLUE}Processing ${secret_name}...${NC}"
    
    if value=$(get_backend_value "$secret_name" "$BACKEND_FILE"); then
        echo -e "  ${GREEN}✓ Found value in backend.hcl${NC}"
        
        # Create/update GitHub secret
        if echo "$value" | gh secret set "$secret_name"; then
            echo -e "  ${GREEN}✅ GitHub secret '${secret_name}' created/updated${NC}"
        else
            echo -e "  ${RED}❌ Failed to create GitHub secret '${secret_name}'${NC}"
        fi
    else
        echo -e "  ${RED}❌ Value not found in backend.hcl${NC}"
        missing_values+=("${secret_name} - expected in backend.hcl")
    fi
done

echo -e "\n${GREEN}🎉 Processing complete!${NC}"

# Report missing values
if [ ${#missing_values[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}⚠️  Missing values that could not be processed:${NC}"
    for missing in "${missing_values[@]}"; do
        echo -e "  ${RED}❌ ${missing}${NC}"
    done
    echo -e "\n${YELLOW}💡 Please add the missing values to the appropriate files and re-run the script.${NC}"
else
    echo -e "\n${GREEN}✅ All secrets have been successfully processed!${NC}"
fi

echo -e "\n${BLUE}📁 Files checked:${NC}"
echo -e "  • terraform.tfvars: $([ -f "$TFVARS_FILE" ] && echo "✓ Found" || echo "❌ Missing")"
echo -e "  • backend.hcl: $([ -f "$BACKEND_FILE" ] && echo "✓ Found" || echo "❌ Missing")"