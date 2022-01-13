terraform {
  # required version?
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
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
}

resource "azurerm_resource_group" "saeb" {
  name = "SAEB-DataAnalytics-${local.build_environment}"
  location = var.location 

  tags = {
    environment = local.build_environment
    build-version = var.terraform_script_version # good practice to add this to "local" and then use local.var_name everywhere
  }
}