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

# Create storage account for main input and curated CSV files as well as for synapse filesystem
resource "azurerm_storage_account" "saeb_storage" {
  name                     = "stsaebdevca01${random_string.random.result}"
  resource_group_name      = azurerm_resource_group.saeb.name
  location                 = azurerm_resource_group.saeb.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = local.common_tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "saeb_data_lake_fs" {
  name               = "fssynapseworkspace"
  storage_account_id = azurerm_storage_account.saeb_storage.id
}

# Creates all the containers at once
resource "azurerm_storage_container" "saeb_storage_container" {
  for_each              = toset(var.storage_containers)
  name                  = each.key
  storage_account_name  = azurerm_storage_account.saeb_storage.name
  container_access_type = "private"
}

# Create Databricks workspace and clusters and associate with a repo
resource "azurerm_databricks_workspace" "saeb_databricks_workspace" {
  name                = "dbw-saeb-dev-01-${random_string.random.result}"
  resource_group_name = azurerm_resource_group.saeb.name
  location            = azurerm_resource_group.saeb.location
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

# more info: https://docs.microsoft.com/en-us/azure/databricks/dev-tools/terraform/
resource "databricks_repo" "saeb_databricks_repo" {
  url = "https://github.com/DTS-STN/AP-Databricks.git"
}

# Create logic app + storage account + app service plan that all work together
resource "azurerm_storage_account" "saeb_logic_app_storage" {
  name                     = "salogicappdevca02${random_string.random.result}"
  resource_group_name      = azurerm_resource_group.saeb.name
  location                 = azurerm_resource_group.saeb.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "saeb_service_plan" {
  name                = "asp-saeb-dev-02-${random_string.random.result}"
  location            = azurerm_resource_group.saeb.location
  resource_group_name = azurerm_resource_group.saeb.name

  sku {
    tier = "WorkflowStandard"
    size = "WS1"
  }
}

resource "azurerm_logic_app_standard" "saeb_logic_app" {
  name                       = "logic-saeb-dev-01-${random_string.random.result}"
  location                   = azurerm_resource_group.saeb.location
  resource_group_name        = azurerm_resource_group.saeb.name
  app_service_plan_id        = azurerm_app_service_plan.saeb_service_plan.id
  storage_account_name       = azurerm_storage_account.saeb_logic_app_storage.name
  storage_account_access_key = azurerm_storage_account.saeb_logic_app_storage.primary_access_key
}

# Create Synapse workspace with dedicated SQL Pool
resource "azurerm_synapse_workspace" "saeb_synapse" {
  name                                 = "synw-saeb-dev-01-${random_string.random.result}"
  resource_group_name                  = azurerm_resource_group.saeb.name
  location                             = azurerm_resource_group.saeb.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.saeb_data_lake_fs.id
  sql_administrator_login              = "sqladminuser"
  sql_administrator_login_password     = "H@Sh1CoR3!"
}

resource "azurerm_synapse_sql_pool" "saeb_synapse_sqlpool" {
  name                 = "syn_sqlpool_saeb_dev_01"
  synapse_workspace_id = azurerm_synapse_workspace.saeb_synapse.id
  sku_name             = "DW100c"
  create_mode          = "Default"
}