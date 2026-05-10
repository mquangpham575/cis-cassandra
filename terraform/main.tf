# =============================================================================
# main.tf — Provider, backend, Resource Group, VNet, Subnet
# =============================================================================

# ---------------------------------------------------------------------------
# Remote State — Azure Blob Storage backend
# Uncomment the terraform{} block below and fill in your values BEFORE running
# `terraform init` for the first time.
# Pre-requisites:
#   az group create -n tfstate-rg -l "Southeast Asia"
#   az storage account create -n <SA_NAME> -g tfstate-rg --sku Standard_LRS
#   az storage container create -n tfstate --account-name <SA_NAME>
# ---------------------------------------------------------------------------

/*
terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "sttfstate1465"
    container_name       = "tfstate"
    key                  = "cis-cassandra/terraform.tfstate"
  }
}
*/

# ---------------------------------------------------------------------------
# Provider — pin to azurerm ~> 3.0 to avoid breaking changes from v4
# ---------------------------------------------------------------------------
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "azurerm" {
  skip_provider_registration = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# ---------------------------------------------------------------------------
# Resource Group — logical container for every resource in this project
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    project     = var.project_name
    environment = "dev"
    managed_by  = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Master Virtual Network — hosts the jump host in the master region
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "master" {
  name                = "${var.project_name}-master-vnet"
  address_space       = [local.master_vnet_cidr]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    project = var.project_name
  }
}

# ---------------------------------------------------------------------------
# DB Virtual Network — hosts the Cassandra nodes in the db region
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "db" {
  name                = "${var.project_name}-db-vnet"
  address_space       = [local.db_vnet_cidr]
  location            = var.db_location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    project = var.project_name
  }
}

# ---------------------------------------------------------------------------
# Master Subnet — hosts only the jump host (10.1.1.10)
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "master" {
  name                 = "${var.project_name}-master-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.master.name
  address_prefixes     = [local.master_subnet_cidr]
}

# ---------------------------------------------------------------------------
# DB Subnet — hosts all 3 Cassandra nodes (10.0.1.11-13)
# NSG is associated in nsg.tf via azurerm_subnet_network_security_group_association
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "cassandra" {
  name                 = "${var.project_name}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.db.name
  address_prefixes     = [local.db_subnet_cidr]
}

# ---------------------------------------------------------------------------
# Bidirectional VNet peering — enables private connectivity between regions
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network_peering" "master_to_db" {
  name                      = "${var.project_name}-master-to-db"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.master.name
  remote_virtual_network_id = azurerm_virtual_network.db.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "db_to_master" {
  name                      = "${var.project_name}-db-to-master"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.db.name
  remote_virtual_network_id = azurerm_virtual_network.master.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
