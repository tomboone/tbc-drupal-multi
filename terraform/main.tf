# Reference the VNet created in your other project
data "azurerm_virtual_network" "main" {
  name                = var.existing_vnet_name
  resource_group_name = var.existing_vnet_rg_name
}

data "azurerm_subnet" "integration" {
  name                 = "IntegrationSubnet"
  virtual_network_name = data.azurerm_virtual_network.main.name
  resource_group_name  = data.azurerm_virtual_network.main.resource_group_name
}

data "azurerm_subnet" "private_endpoints" {
  name                 = "PrivateEndpointsSubnet"
  virtual_network_name = data.azurerm_virtual_network.main.name
  resource_group_name  = data.azurerm_virtual_network.main.resource_group_name
}

locals {
  webapp_name = "tbc-drupal-multi"

  # Production sites and their database users
  prod_databases = {
    jeanneandtom = "jat",
    jeannebriggs = "jbc",
    rsstomboone  = "rsstbc"
  }

  # Staging sites and their database users
  stage_databases = {
    jeanneandtom = "jats",
    jeannebriggs = "jbcs",
    rsstomboone  = "rsstbcs"
  }

  # All databases to create (combines prod + stage)
  all_databases = merge(
    { for site, user in local.prod_databases : site => user },
    { for site, user in local.stage_databases : "${site}_stage" => user }
  )
}

data "azurerm_service_plan" "existing" {
  name                = var.existing_app_service_plan_name
  resource_group_name = var.existing_app_service_plan_resource_group
}

data "azurerm_mysql_flexible_server" "existing" {
  name = var.existing_mysql_flexible_server_name
  resource_group_name = var.existing_mysql_flexible_server_rg_name
}

data "azurerm_log_analytics_workspace" "existing" {
  name = var.existing_log_analytics_workspace_name
  resource_group_name = var.existing_log_analytics_workspace_rg_name
}

resource "azurerm_resource_group" "main" {
  name = "${local.webapp_name}-rg"
  location = data.azurerm_service_plan.existing.location
}

resource "azurerm_mysql_flexible_database" "main" {
  for_each = local.all_databases
  name = each.key
  server_name = data.azurerm_mysql_flexible_server.existing.name
  resource_group_name = data.azurerm_mysql_flexible_server.existing.resource_group_name
  charset = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}

resource "random_password" "main" {
  for_each = local.all_databases
  length = 16
  special = false
}

resource "mysql_user" "main" {
  for_each = local.all_databases
  user = each.value
  plaintext_password = random_password.main[each.key].result
  host = "%"
  depends_on = [azurerm_mysql_flexible_database.main, random_password.main]
}

resource "mysql_grant" "main" {
  for_each = local.all_databases
  user = each.value
  host = mysql_user.main[each.key].host
  database = each.key
  privileges = ["ALL PRIVILEGES"]
  depends_on = [azurerm_mysql_flexible_database.main, mysql_user.main]
}

resource "azurerm_storage_account" "sites_storage" {
  name                     = "${replace(local.webapp_name, "-", "")}sa"
  resource_group_name      = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  public_network_access_enabled = false
}

resource "azurerm_storage_share" "sites_share_prod" {
  name                 = "sites-prod"
  storage_account_id = azurerm_storage_account.sites_storage.id
  quota                = 10
}

resource "azurerm_storage_share" "sites_share_stage" {
  name               = "sites-stage"
  storage_account_id = azurerm_storage_account.sites_storage.id
  quota              = 10
}

# Private endpoint for Storage Account
resource "azurerm_private_endpoint" "storage" {
  name                = "${local.webapp_name}-storage-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = data.azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "${local.webapp_name}-storage-psc"
    private_connection_resource_id = azurerm_storage_account.sites_storage.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "storage-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage.id]
  }
}

# Private DNS Zone for Storage
resource "azurerm_private_dns_zone" "storage" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage" {
  name                  = "${local.webapp_name}-storage-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.storage.name
  virtual_network_id    = data.azurerm_virtual_network.main.id
}

# Note: Subnet delegation needs to be added to the existing subnet
# Since we're using a data source for an existing subnet, 
# the delegation should be added via Azure CLI or in the VNet project:
# az network vnet subnet update --resource-group <vnet-rg> --vnet-name <vnet-name> --name IntegrationSubnet --delegations Microsoft.Web/serverFarms

# Application Insights for monitoring
resource "azurerm_application_insights" "main" {
  name                = "${local.webapp_name}-insights"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = data.azurerm_log_analytics_workspace.existing.id
  application_type    = "web"
}

resource "azurerm_linux_web_app" "main" {
  name                = local.webapp_name
  resource_group_name = azurerm_resource_group.main.name
  location            = data.azurerm_service_plan.existing.location
  service_plan_id     = data.azurerm_service_plan.existing.id

  virtual_network_subnet_id = data.azurerm_subnet.integration.id

  site_config {
    always_on = true
    application_stack {
      php_version = "8.4"
    }
  }

  storage_account {
    name         = "sites-storage"
    type         = "AzureFiles"
    account_name = azurerm_storage_account.sites_storage.name
    access_key   = azurerm_storage_account.sites_storage.primary_access_key
    share_name   = azurerm_storage_share.sites_share_prod.name
    mount_path   = "/home/site/wwwroot/web/sites"
  }

  app_settings = {
    "https_only" = "true"
    "DRUPAL_ENV" = "prod"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.main.instrumentation_key
  }
}

# Create staging deployment slot
resource "azurerm_linux_web_app_slot" "stage" {
  name           = "stage"
  app_service_id = azurerm_linux_web_app.main.id

  virtual_network_subnet_id = data.azurerm_subnet.integration.id

  site_config {
    always_on = true
    application_stack {
      php_version = "8.4"
    }
  }

  storage_account {
    name         = "sites-storage"
    type         = "AzureFiles"
    account_name = azurerm_storage_account.sites_storage.name
    access_key   = azurerm_storage_account.sites_storage.primary_access_key
    share_name   = azurerm_storage_share.sites_share_stage.name
    mount_path   = "/home/site/wwwroot/web/sites"
  }

  app_settings = {
    "https_only" = "true"
    "DRUPAL_ENV" = "stage"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.main.instrumentation_key
  }
}

