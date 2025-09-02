# Azure Infrastructure with Terraform

This directory contains Terraform configuration for managing the Azure infrastructure for the TBC Drupal application.

## Overview

The Terraform configuration provisions:
- Azure Resource Group
- Linux Web App for the Drupal application (using an existing App Service Plan)

## Prerequisites

1. **Azure CLI**: Install and authenticate with Azure
   ```bash
   az login
   ```

2. **Terraform**: Install Terraform >= 1.0
   ```bash
   # On macOS with Homebrew
   brew install terraform
   ```

## Setup

1. **Copy the example variables file:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars`** with your values:
   - Set `existing_app_service_plan_name` to your existing App Service Plan name
   - Set `existing_app_service_plan_resource_group` to the resource group containing your App Service Plan
   - Configure other values as needed

3. **Configure backend (optional):**
   ```bash
   cp backend.tf.example backend.tf
   # Edit backend.tf with your Azure Storage Account details
   ```

## Usage

### Initialize Terraform
```bash
cd terraform/
terraform init
```

### Plan the deployment
```bash
terraform plan
```

### Apply the configuration
```bash
terraform apply
```

### Import existing resources (if migrating)
If you have existing Azure resources, you can import them:

```bash
# Import resource group
terraform import azurerm_resource_group.main /subscriptions/{subscription-id}/resourceGroups/{resource-group-name}

# Note: App Service Plan import not needed since we're using an existing one via data source

# Import web app
terraform import azurerm_linux_web_app.main /subscriptions/{subscription-id}/resourceGroups/{resource-group-name}/providers/Microsoft.Web/sites/{web-app-name}
```

Replace the placeholders with your actual Azure subscription ID and resource names.

### Get outputs
```bash
terraform output
```

## GitHub Actions Integration

After applying Terraform, you'll need to update your GitHub Actions workflow:

1. Get the publish profile from Azure:
   ```bash
   az webapp deployment list-publishing-profiles --resource-group $(terraform output -raw resource_group_name) --name $(terraform output -raw webapp_name) --xml
   ```

2. Update the `AZURE_WEBAPP_PUBLISH_PROFILE` secret in your GitHub repository

## Files

- `main.tf` - Main Terraform configuration
- `variables.tf` - Variable definitions
- `outputs.tf` - Output definitions
- `terraform.tfvars.example` - Example variables file
- `backend.tf.example` - Example backend configuration

## Important Notes

- The current configuration assumes you're migrating from existing Azure resources
- Make sure to backup any existing configurations before applying
- The web app configuration matches your current PHP 8.3 setup
- Always run `terraform plan` before `terraform apply`