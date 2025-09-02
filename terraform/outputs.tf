output "resource_group_name" {
  description = "Name of the existing resource group"
  value       = azurerm_linux_web_app.main.resource_group_name
}

output "webapp_name" {
  description = "Name of the web app"
  value       = azurerm_linux_web_app.main.name
}

output "php_version" {
  description = "PHP version used in the web app"
  value       = "8.4"  # Match the version in main.tf
}

output "app_service_plan_id" {
  description = "ID of the existing app service plan"
  value       = data.azurerm_service_plan.existing.id
}

output "app_service_plan_name" {
  description = "Name of the existing app service plan"
  value       = data.azurerm_service_plan.existing.name
}

# Database connection details for Drupal settings.php
output "mysql_host" {
  description = "MySQL server hostname"
  value       = data.azurerm_mysql_flexible_server.existing.fqdn
}

output "mysql_port" {
  description = "MySQL server port"
  value       = 3306
}

output "prod_database_names" {
  description = "Map of production site names to database names"
  value       = local.prod_databases
}

output "stage_database_names" {
  description = "Map of staging site names to database names (with _stage suffix)"
  value       = { for site, user in local.stage_databases : "${site}_stage" => user }
}

output "all_database_connections" {
  description = "All database connection details"
  value = {
    for site, user in local.all_databases : site => {
      host     = data.azurerm_mysql_flexible_server.existing.fqdn
      port     = 3306
      database = site
      username = user
      password = random_password.main[site].result
    }
  }
  sensitive = true
}

output "stage_slot_name" {
  description = "Name of the staging deployment slot"
  value       = azurerm_linux_web_app_slot.stage.name
}

# Storage account details
output "storage_account_name" {
  description = "Name of the sites storage account"
  value       = azurerm_storage_account.sites_storage.name
}

output "storage_account_key" {
  description = "Primary access key for the storage account"
  value       = azurerm_storage_account.sites_storage.primary_access_key
  sensitive   = true
}

output "sites_storage_path" {
  description = "Mount path for sites storage in the web app"
  value       = "/mnt/sites"
}
