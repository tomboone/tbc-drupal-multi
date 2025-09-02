variable "existing_app_service_plan_name" {
  description = "Name of the existing App Service Plan to use"
  type        = string
}

variable "existing_app_service_plan_resource_group" {
  description = "Resource group of the existing App Service Plan"
  type        = string
}

variable "existing_mysql_flexible_server_name" {
  description = "Name of the existing MySQL Flexible Server to use"
  type = string
}

variable "existing_mysql_flexible_server_rg_name" {
  description = "Resource group of the existing MySQL Flexible Server"
  type = string
}

variable "existing_log_analytics_workspace_name" {
  description = "Name of the existing Log Analytics Workspace to use"
  type = string
}

variable "existing_log_analytics_workspace_rg_name" {
  description = "Resource group of the existing Log Analytics Workspace"
  type = string
}

variable "mysql_admin_username" {
  description = "Admin username for the existing MySQL Flexible Server"
  type = string
}

variable "mysql_admin_password" {
  description = "Admin password for the existing MySQL Flexible Server"
  type = string
}
