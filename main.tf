terraform {
  # required version?
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.89.0"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

locals {
  build_environment = var.environment == "production" ? "Prod" : "Dev"
  common_tags = {
    Product      = "SAEB Platform"
    ProductOwner = "Shaun Laughland"
    CreatedBy    = "Ben Larabie"
  }
}

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

  tags = {
    environment = "staging"
  }
}

resource "azurerm_storage_container" "saeb_storage_container" {
  for_each              = toset(var.storage_containers)
  name                  = each.key
  storage_account_name  = azurerm_storage_account.saeb_storage.name
  container_access_type = "private"
}