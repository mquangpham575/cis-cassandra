# =============================================================================
# nsg.tf — Network Security Group rules for the Cassandra cluster
#
# Rule priority map (100–4096, lower = evaluated first):
#   100  SSH from allowed_ssh_cidr
#   200  Cassandra native transport (9042)     — intra-VNet only
#   210  Cassandra inter-node gossip (7000)    — intra-VNet only
#   220  Cassandra JMX (7199)                  — intra-VNet only
#   230  JMX Exporter / Prometheus scrape (9404) — intra-VNet only
#   240  Grafana (3000) intra-VNet             — intra-VNet only
#   250  Prometheus (9090) intra-VNet          — intra-VNet only
#   300  Grafana (3000) external on node1      — internet → node1 PIP only
#   310  Prometheus (9090) external on node1   — internet → node1 PIP only
#  4096  Deny all inbound (explicit, belt-and-suspenders)
#
# NOTE: Rules 300/310 open Grafana & Prometheus from the internet to node1's
# public IP. This is acceptable for a dev/lab setup; tighten allowed_ssh_cidr
# (or add a destination_address_prefix pointing only to node1's PIP) in prod.
# =============================================================================

resource "azurerm_network_security_group" "cassandra" {
  name                = "${var.project_name}-nsg"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  # ---- SSH (port 22) -------------------------------------------------------
  # Source is configurable via var.allowed_ssh_cidr (default: any).
  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_ssh_ips
    destination_address_prefix = "*"
    description                = "SSH access — restrict via allowed_ssh_cidr variable"
  }

  # ---- SSH (port 22) intra-VNet — for lateral administration -------------
  security_rule {
    name                       = "allow-ssh-internal"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = local.vnet_cidr
    destination_address_prefix = local.subnet_cidr
    description                = "SSH access — allow nodes to manage each other"
  }

  # ---- Cassandra native transport (9042) — clients & drivers ---------------
  security_rule {
    name                       = "allow-cassandra-native"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9042"
    source_address_prefix      = local.vnet_cidr
    destination_address_prefix = local.subnet_cidr
    description                = "Cassandra CQL native transport — VNet only"
  }

  # ---- Cassandra gossip / inter-node (7000) --------------------------------
  security_rule {
    name                       = "allow-cassandra-gossip"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7000"
    source_address_prefix      = local.vnet_cidr
    destination_address_prefix = local.subnet_cidr
    description                = "Cassandra gossip / inter-node — VNet only"
  }

  # ---- Cassandra JMX (7199) -----------------------------------------------
  security_rule {
    name                       = "allow-cassandra-jmx"
    priority                   = 220
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7199"
    source_address_prefix      = local.vnet_cidr
    destination_address_prefix = local.subnet_cidr
    description                = "Cassandra JMX — VNet only"
  }

  # ---- JMX Exporter / Prometheus scrape (9404) ----------------------------
  security_rule {
    name                       = "allow-jmx-exporter"
    priority                   = 230
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9404"
    source_address_prefix      = local.vnet_cidr
    destination_address_prefix = local.subnet_cidr
    description                = "JMX Exporter (Prometheus metrics) — VNet only"
  }

  # ---- Grafana (3000) intra-VNet — all nodes ------------------------------
  security_rule {
    name                       = "allow-grafana-vnet"
    priority                   = 240
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = local.vnet_cidr
    destination_address_prefix = local.subnet_cidr
    description                = "Grafana dashboard — intra-VNet access for all nodes"
  }

  # ---- Prometheus (9090) intra-VNet — all nodes ---------------------------
  security_rule {
    name                       = "allow-prometheus-vnet"
    priority                   = 250
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9090"
    source_address_prefix      = local.vnet_cidr
    destination_address_prefix = local.subnet_cidr
    description                = "Prometheus — intra-VNet access for all nodes"
  }

  # ---- ICMP (Ping) intra-VNet — all nodes ---------------------------------
  security_rule {
    name                       = "allow-icmp-vnet"
    priority                   = 260
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = local.vnet_cidr
    destination_address_prefix = local.subnet_cidr
    description                = "ICMP (Ping) — intra-VNet access for diagnostics"
  }

  # ---- Grafana (3000) external — node1 (seed/monitoring node) only --------
  # node1 hosts Grafana and is the only VM that should be internet-reachable
  # on port 3000. The destination_address_prefix is set to the node1 PIP at
  # plan time so traffic to node2/node3 PIPs is not allowed by this rule.
  security_rule {
    name                       = "allow-grafana-external-node1"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = azurerm_public_ip.node[local.seed_node_key].ip_address
    description                = "Grafana external access — node1 public IP only"
  }

  # ---- Prometheus (9090) external — node1 only ----------------------------
  security_rule {
    name                       = "allow-prometheus-external-node1"
    priority                   = 310
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9090"
    source_address_prefix      = "*"
    destination_address_prefix = azurerm_public_ip.node[local.seed_node_key].ip_address
    description                = "Prometheus external access — node1 public IP only"
  }

  # ---- Explicit deny-all inbound (belt-and-suspenders) --------------------
  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Catch-all deny — anything not explicitly allowed above is dropped"
  }

  tags = {
    project = var.project_name
  }
}

# ---------------------------------------------------------------------------
# Associate the NSG with the Cassandra subnet
# All VMs in the subnet inherit these rules regardless of NIC-level NSGs.
# ---------------------------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "cassandra" {
  subnet_id                 = azurerm_subnet.cassandra.id
  network_security_group_id = azurerm_network_security_group.cassandra.id
}
