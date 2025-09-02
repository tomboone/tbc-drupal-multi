terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">=3.0"
    }
    mysql = {
      source  = "petoju/mysql"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "mysql" {
  endpoint = data.azurerm_mysql_flexible_server.existing.fqdn
  username = var.mysql_admin_username
  password = var.mysql_admin_password
  
  # SSL configuration for Azure MySQL Flexible Server
  tls = "true"
}
