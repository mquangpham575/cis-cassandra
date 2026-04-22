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
  # One entry per Cassandra node; node1 is the seed node
  nodes = {
    node1 = { ip = "10.0.1.11", index = 1, is_seed = true }
    node2 = { ip = "10.0.1.12", index = 2, is_seed = false }
    node3 = { ip = "10.0.1.13", index = 3, is_seed = false }
  }

  # CIDR of the VNet — used as source in intra-cluster NSG rules
  vnet_cidr   = "10.0.0.0/16"
  subnet_cidr = "10.0.1.0/24"

  # Seed node key for Grafana/Prometheus external exposure rule
  seed_node_key = "node1"
}
