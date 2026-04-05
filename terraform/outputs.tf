# =============================================================================
# outputs.tf — Useful values printed after `terraform apply`
# =============================================================================

# ---------------------------------------------------------------------------
# Public IPs — needed to SSH into each node from outside the VNet
# ---------------------------------------------------------------------------
output "public_ips" {
  description = "Public IP addresses for each Cassandra node"
  value = {
    for k, pip in azurerm_public_ip.node : k => pip.ip_address
  }
}

# ---------------------------------------------------------------------------
# Private IPs — static, used by Cassandra seed config and intra-cluster comms
# ---------------------------------------------------------------------------
output "private_ips" {
  description = "Static private IP addresses for each Cassandra node"
  value = {
    for k, node in local.nodes : k => node.ip
  }
}

# ---------------------------------------------------------------------------
# SSH commands — copy-paste ready after apply
# ---------------------------------------------------------------------------
output "ssh_commands" {
  description = "Ready-to-run SSH commands for each node (user: cassandra)"
  value = {
    for k, pip in azurerm_public_ip.node :
    k => "ssh cassandra@${pip.ip_address}"
  }
}

# ---------------------------------------------------------------------------
# Cassandra seed address — needed by Ansible/scripts to configure cassandra.yaml
# ---------------------------------------------------------------------------
output "seed_node_private_ip" {
  description = "Private IP of the seed node (node1) — set as seeds in cassandra.yaml"
  value       = local.nodes[local.seed_node_key].ip
}

# ---------------------------------------------------------------------------
# Grafana URL — node1 exposes port 3000 externally
# ---------------------------------------------------------------------------
output "grafana_url" {
  description = "Grafana dashboard URL (served from node1)"
  value       = "http://${azurerm_public_ip.node[local.seed_node_key].ip_address}:3000"
}

# ---------------------------------------------------------------------------
# Prometheus URL — node1 exposes port 9090 externally
# ---------------------------------------------------------------------------
output "prometheus_url" {
  description = "Prometheus UI URL (served from node1)"
  value       = "http://${azurerm_public_ip.node[local.seed_node_key].ip_address}:9090"
}

# ---------------------------------------------------------------------------
# Resource Group name — handy for follow-up `az` CLI commands
# ---------------------------------------------------------------------------
output "resource_group_name" {
  description = "Azure Resource Group containing all cis-cassandra resources"
  value       = azurerm_resource_group.main.name
}
