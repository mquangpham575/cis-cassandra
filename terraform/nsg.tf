# =============================================================================
# nsg.tf — Network Security Group rules for the Cassandra cluster
#
# Rule priority map (100–4096, lower = evaluated first):
#   100  SSH from allowed_ssh_cidr
#   200  Cassandra native transport (9042)     — intra-VNet only
#   210  Cassandra inter-node gossip (7000)    — intra-VNet only
#   220  Cassandra JMX (7199)                  — intra-VNet only
#   260  ICMP (Ping)                           — intra-VNet only
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
