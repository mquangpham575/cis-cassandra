# =============================================================================
# nsg.tf — Regional Network Security Groups for the Cassandra cluster
#
# Two NSGs are required because the master and database nodes live in different
# Azure regions and therefore attach to different regional subnets.
# =============================================================================

locals {
  peered_vnet_sources = [local.master_vnet_cidr, local.db_vnet_cidr]
}

resource "azurerm_network_security_group" "master" {
  name                = "${var.project_name}-master-nsg"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

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
    description                = "SSH access for the master node"
  }

  security_rule {
    name                       = "allow-ssh-internal"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = local.peered_vnet_sources
    destination_address_prefix = "*"
    description                = "SSH access between peered VNets"
  }

  security_rule {
    name                       = "allow-vite-dev-server"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5173"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Vite dev server access for the master node"
  }

  security_rule {
    name                       = "allow-cassandra-native"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9042"
    source_address_prefixes    = local.peered_vnet_sources
    destination_address_prefix = "*"
    description                = "Cassandra CQL native transport"
  }

  security_rule {
    name                       = "allow-cassandra-gossip"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7000"
    source_address_prefixes    = local.peered_vnet_sources
    destination_address_prefix = "*"
    description                = "Cassandra gossip and inter-node traffic"
  }

  security_rule {
    name                       = "allow-cassandra-jmx"
    priority                   = 220
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7199"
    source_address_prefixes    = local.peered_vnet_sources
    destination_address_prefix = "*"
    description                = "Cassandra JMX traffic"
  }

  security_rule {
    name                       = "allow-icmp-vnet"
    priority                   = 260
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = local.peered_vnet_sources
    destination_address_prefix = "*"
    description                = "ICMP for diagnostics across peered VNets"
  }

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
    description                = "Catch-all deny for inbound traffic"
  }

  tags = {
    project = var.project_name
    role    = "master"
  }
}

resource "azurerm_network_security_group" "cassandra" {
  name                = "${var.project_name}-db-nsg"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.db_location

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
    description                = "SSH access for the database nodes"
  }

  security_rule {
    name                       = "allow-ssh-internal"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = local.peered_vnet_sources
    destination_address_prefix = "*"
    description                = "SSH access between peered VNets"
  }

  security_rule {
    name                       = "allow-cassandra-native"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9042"
    source_address_prefixes    = local.peered_vnet_sources
    destination_address_prefix = "*"
    description                = "Cassandra CQL native transport"
  }

  security_rule {
    name                       = "allow-cassandra-gossip"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7000"
    source_address_prefixes    = local.peered_vnet_sources
    destination_address_prefix = "*"
    description                = "Cassandra gossip and inter-node traffic"
  }

  security_rule {
    name                       = "allow-cassandra-jmx"
    priority                   = 220
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7199"
    source_address_prefixes    = local.peered_vnet_sources
    destination_address_prefix = "*"
    description                = "Cassandra JMX traffic"
  }

  security_rule {
    name                       = "allow-icmp-vnet"
    priority                   = 260
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = local.peered_vnet_sources
    destination_address_prefix = "*"
    description                = "ICMP for diagnostics across peered VNets"
  }

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
    description                = "Catch-all deny for inbound traffic"
  }

  tags = {
    project = var.project_name
    role    = "db"
  }
}

# ---------------------------------------------------------------------------
# Associate each subnet with the correct regional NSG
# ---------------------------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "master" {
  subnet_id                 = azurerm_subnet.master.id
  network_security_group_id = azurerm_network_security_group.master.id
}

resource "azurerm_subnet_network_security_group_association" "cassandra" {
  subnet_id                 = azurerm_subnet.cassandra.id
  network_security_group_id = azurerm_network_security_group.cassandra.id
}
