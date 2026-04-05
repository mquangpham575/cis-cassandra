# =============================================================================
# variables.tf — Input variables for cis-cassandra Azure infrastructure
# =============================================================================

variable "project_name" {
  description = "Project name used as a prefix for all resource names"
  type        = string
  default     = "cis-cassandra"
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group to create all resources in"
  type        = string
  default     = "rg-cis-cassandra"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "Southeast Asia"
}

variable "vm_size" {
  description = "Azure VM SKU"
  type        = string
  default     = "Standard_B2ps_v2"
}

variable "ssh_public_key_path" {
  description = "Absolute path to the SSH public key file (.pub) used for VM authentication. Password auth is disabled."
  type        = string
  default     = "~/.ssh/cis_key.pub"
}

variable "allowed_ssh_cidr" {
  description = <<-EOT
    CIDR block allowed to reach port 22 on the VMs.
    Default 0.0.0.0/0 keeps things flexible for the team during development.
    Tighten this to your group's static egress IP in production, e.g. "203.0.113.0/32".
  EOT
  type    = string
  default = "14.187.93.155/32"
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
