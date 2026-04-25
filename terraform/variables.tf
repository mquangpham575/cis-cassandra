# =============================================================================
# variables.tf — Input variables for cis-cassandra Azure infrastructure
# =============================================================================

variable "project_name" {
  description = "Project name used as a prefix for all resource names"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group to create all resources in"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
}

variable "vm_size" {
  description = "Azure VM SKU"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Absolute path to the SSH public key file (.pub) used for VM authentication. Password auth is disabled."
  type        = string
}

variable "allowed_ssh_ips" {
  description = <<-EOT
    List of CIDR blocks allowed to reach port 22 on the VMs.
    Include your teammates' public IPs here.
  EOT
  type    = list(string)
}

# ---------------------------------------------------------------------------
# Derived locals — centralise names so every resource uses the same pattern
# ---------------------------------------------------------------------------
locals {
  # 1 Master (Management) and 3 Database nodes
  nodes = {
    master = { ip = "10.0.1.10", role = "master", is_seed = false }
    db1    = { ip = "10.0.1.11", role = "db",     is_seed = true }
    db2    = { ip = "10.0.1.12", role = "db",     is_seed = false }
    db3    = { ip = "10.0.1.13", role = "db",     is_seed = false }
  }

  # CIDR of the VNet — used as source in intra-cluster NSG rules
  vnet_cidr   = "10.0.0.0/16"
  subnet_cidr = "10.0.1.0/24"

  # DB1 is the primary seed for the cluster
  seed_node_key = "db1"
}
