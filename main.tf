# Declare some local variables
locals {
  build_environment = var.environment == "production" ? "Prod" : "Dev"
  common_tags = {
    Product      = "SAEB Platform"
    ProductOwner = "Shaun Laughland"
    CreatedBy    = "Terraform"
  }
}

# Create Azure resource group
resource "azurerm_resource_group" "saeb" {
  name     = "SAEB-DataAnalytics-${local.build_environment}"
  location = var.location 

  tags = merge(
    local.common_tags,
    {
      Environment = local.build_environment
      BuildVersion = var.terraform_script_version
    }
  )
}

# Create ADF
resource "azurerm_data_factory" "saeb_adf" {
  name                = "adf-saeb-dev-01-${random_string.random.result}"
  location            = azurerm_resource_group.saeb.location
  resource_group_name = azurerm_resource_group.saeb.name
}

resource "random_string" "random" {
  length = 4
  upper = false
  special = false
  number = false
}

resource "azurerm_storage_account" "saeb_storage" {
  name                     = "stsaebdevca01${random_string.random.result}"
  resource_group_name      = azurerm_resource_group.saeb.name
  location                 = azurerm_resource_group.saeb.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = local.common_tags
}

# Creates all the containers at once
resource "azurerm_storage_container" "saeb_storage_container" {
  for_each              = toset(var.storage_containers)
  name                  = each.key
  storage_account_name  = azurerm_storage_account.saeb_storage.name
  container_access_type = "private"
}

# Create Databricks workspace and clusters
resource "azurerm_databricks_workspace" "saeb_databricks_workspace" {
  name                = "dbw-saeb-dev-01-${random_string.random.result}"
  resource_group_name = azurerm_resource_group.saeb.name
  location            = var.location
  sku                 = "standard"

  tags = local.common_tags
}

resource "databricks_cluster" "saeb_databricks_autoscaling" {
  cluster_name            = "terraform_stnd12"
  spark_version           = "7.3.x-scala2.12"
  node_type_id            = "Standard_DS3_v2"
  # node_type_id            = data.databricks_node_type.smallest.id
  autotermination_minutes = 20
  autoscale {
    min_workers = 0
    max_workers = 1
  }
}
