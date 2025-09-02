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
  name                     = "${replace(local.webapp_name, "-", "")}sites"
  resource_group_name      = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    Environment = "production"
    Purpose     = "drupal-sites-storage"
  }
}

resource "azurerm_storage_share" "sites_share" {
  name                 = "sites"
  storage_account_id = azurerm_storage_account.sites_storage.id
  quota                = 10  # 10GB - adjust as needed
}

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
    share_name   = azurerm_storage_share.sites_share.name
    mount_path   = "/mnt/sites"
  }

  app_settings = {
    "https_only" = "true"
    "SITES_STORAGE_PATH" = "/mnt/sites"
    "DRUPAL_ENV" = "production"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.main.instrumentation_key
    "STARTUP_COMMAND" = "/mnt/sites/startup.sh"
  }

  sticky_settings {
    app_setting_names = [
      "DRUPAL_ENV"
    ]
  }
}

# Create staging deployment slot
resource "azurerm_linux_web_app_slot" "stage" {
  name           = "stage"
  app_service_id = azurerm_linux_web_app.main.id

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
    share_name   = azurerm_storage_share.sites_share.name
    mount_path   = "/mnt/sites"
  }

  app_settings = {
    "https_only" = "true"
    "SITES_STORAGE_PATH" = "/mnt/sites"
    "DRUPAL_ENV" = "staging"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    "STARTUP_COMMAND" = "/mnt/sites/startup.sh"
  }
}

