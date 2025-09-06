#!/bin/bash

# Script to convert Terraform variables to GitHub Actions environment variables
# Usage: ./tf-vars-to-github-env.sh <terraform-variables-file> <github-workflow-file>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check arguments
if [ $# -ne 2 ]; then
    echo -e "${RED}❌ Usage: $0 <terraform-variables-file> <github-workflow-file>${NC}"
    echo "Example: $0 terraform/variables.tf .github/workflows/deploy.yml"
    exit 1
fi

TF_VARS_FILE="$1"
GITHUB_WORKFLOW_FILE="$2"

# Validate input files
if [ ! -f "$TF_VARS_FILE" ]; then
    echo -e "${RED}❌ Terraform variables file not found: $TF_VARS_FILE${NC}"
    exit 1
fi

if [ ! -f "$GITHUB_WORKFLOW_FILE" ]; then
    echo -e "${RED}❌ GitHub workflow file not found: $GITHUB_WORKFLOW_FILE${NC}"
    exit 1
fi

echo -e "${YELLOW}🔄 Processing Terraform variables from: $TF_VARS_FILE${NC}"
echo -e "${YELLOW}📝 Updating GitHub workflow file: $GITHUB_WORKFLOW_FILE${NC}"

# Create backup of workflow file
cp "$GITHUB_WORKFLOW_FILE" "${GITHUB_WORKFLOW_FILE}.backup"
echo -e "${GREEN}📋 Backup created: ${GITHUB_WORKFLOW_FILE}.backup${NC}"

# Extract variable names from Terraform file
# This matches: variable "variable_name" {
VARIABLES=$(grep -E '^[[:space:]]*variable[[:space:]]+"[^"]+".+\{' "$TF_VARS_FILE" | sed 's/.*variable[[:space:]]*"\([^"]*\)".*/\1/' | sort | uniq)

if [ -z "$VARIABLES" ]; then
    echo -e "${YELLOW}⚠️  No variables found in $TF_VARS_FILE${NC}"
    exit 0
fi

echo -e "${YELLOW}Found variables:${NC}"
for var in $VARIABLES; do
    echo "  - $var"
done

# Function to convert secret name to uppercase with underscores
to_upper_case() {
    echo "$1" | tr '[:lower:]' '[:upper:]' | sed 's/-/_/g'
}

# Function to check if environment variable already exists in workflow
env_var_exists() {
    local env_var="$1"
    local file="$2"
    grep -q "TF_VAR_${env_var}:" "$file"
}

# Function to find the env: section and add variables
add_env_vars() {
    local workflow_file="$1"
    local new_vars=()
    
    # Check which variables need to be added
    for var in $VARIABLES; do
        upper_var=$(to_upper_case "$var")
        if ! env_var_exists "$var" "$workflow_file"; then
            new_vars+=("$var:$upper_var")
        else
            echo -e "${YELLOW}⏭️  TF_VAR_${var} already exists, skipping${NC}"
        fi
    done
    
    if [ ${#new_vars[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ All variables already exist in workflow file${NC}"
        return 0
    fi
    
    # Create temporary file
    local temp_file=$(mktemp)
    local in_env_section=false
    local env_section_found=false
    local env_indentation=""
    
    while IFS= read -r line; do
        echo "$line" >> "$temp_file"
        
        # Detect env: section
        if [[ "$line" =~ ^[[:space:]]*env:[[:space:]]*$ ]]; then
            env_section_found=true
            in_env_section=true
            env_indentation=$(echo "$line" | sed 's/env:.*//')
            
            # Add new variables right after env: line
            for var_pair in "${new_vars[@]}"; do
                IFS=':' read -r original_var upper_var <<< "$var_pair"
                echo "${env_indentation}  TF_VAR_${original_var}: \${{ secrets.${upper_var} }}" >> "$temp_file"
                echo -e "${GREEN}✅ Added: TF_VAR_${original_var}${NC}"
            done
        # Detect when we leave env section (next top-level key)
        elif $in_env_section && [[ "$line" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]] ]] && [[ ! "$line" =~ ^[[:space:]]{2,} ]]; then
            in_env_section=false
        fi
    done < "$workflow_file"
    
    # If no env: section found, we need to add one
    if ! $env_section_found; then
        echo -e "${YELLOW}⚠️  No env: section found in workflow file${NC}"
        echo -e "${YELLOW}You'll need to manually add an env: section with these variables:${NC}"
        for var_pair in "${new_vars[@]}"; do
            IFS=':' read -r original_var upper_var <<< "$var_pair"
            echo "  TF_VAR_${original_var}: \${{ secrets.${upper_var} }}"
        done
        rm "$temp_file"
        return 1
    fi
    
    # Replace original file with modified version
    mv "$temp_file" "$workflow_file"
    echo -e "${GREEN}✅ Updated workflow file successfully${NC}"
}

# Process the workflow file
add_env_vars "$GITHUB_WORKFLOW_FILE"

echo -e "\n${GREEN}🎉 Processing complete!${NC}"
echo -e "${YELLOW}📋 Remember to add these secrets to your GitHub repository:${NC}"

for var in $VARIABLES; do
    upper_var=$(to_upper_case "$var")
    echo "  - ${upper_var}"
done

echo -e "\n${YELLOW}💡 You can restore the original file from: ${GITHUB_WORKFLOW_FILE}.backup${NC}"