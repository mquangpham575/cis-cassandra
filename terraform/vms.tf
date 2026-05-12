# =============================================================================
# vms.tf — Public IPs, NICs, and Linux VMs for the 3-node Cassandra cluster
# =============================================================================

# ---------------------------------------------------------------------------
# cloud-init script (base64-encoded) — runs once at first boot
# Installs: OpenJDK 11, Python 3.10, Apache Cassandra 4.0
# Cassandra is installed via the official Apache apt repo so version is fixed.
# ---------------------------------------------------------------------------
locals {
  # Shared baseline for all management
  common_packages = ["apt-transport-https", "gnupg", "curl", "python3.10", "python3-pip"]
  # Database specific dependencies
  db_packages     = ["openjdk-11-jdk"]

  # Identify the seed node IP dynamically from the nodes map
  seed_node_ip = local.nodes[local.seed_node_key].ip
}

# Public IPs — ONLY for the Master node due to subscription limits
resource "azurerm_public_ip" "node" {
  for_each = { for k, v in local.nodes : k => v if v.role == "master" }

  name                = "${var.project_name}-${each.key}-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    project = var.project_name
    node    = each.key
  }
}

# ---------------------------------------------------------------------------
# Network Interfaces — static private IP so Cassandra seed address is stable
# ---------------------------------------------------------------------------
resource "azurerm_network_interface" "node" {
  for_each = local.nodes

  name                = "${var.project_name}-${each.key}-nic"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.cassandra.id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.ip
    # Only associate Public IP if it exists for this node
    public_ip_address_id          = lookup(azurerm_public_ip.node, each.key, null) != null ? azurerm_public_ip.node[each.key].id : null
  }

  tags = {
    project = var.project_name
    node    = each.key
  }
}

# ---------------------------------------------------------------------------
# Associate each NIC with the Cassandra NSG defined in nsg.tf
# ---------------------------------------------------------------------------
resource "azurerm_network_interface_security_group_association" "node" {
  for_each = local.nodes

  network_interface_id      = azurerm_network_interface.node[each.key].id
  network_security_group_id = azurerm_network_security_group.cassandra.id
}

# ---------------------------------------------------------------------------
# Linux Virtual Machines — Ubuntu 22.04 LTS
# ---------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "node" {
  for_each = local.nodes

  name                = "${var.project_name}-${each.key}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = (each.value.role == "master") ? var.master_vm_size : var.vm_size

  admin_username                  = "cassandra"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "cassandra"
    public_key = file(var.ssh_public_key_path)
  }

  network_interface_ids = [azurerm_network_interface.node[each.key].id]

  os_disk {
    name                 = "${var.project_name}-${each.key}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # DYNAMIC CLOUD-INIT: Injects the specific node's IP and the cluster seed IP
  custom_data = base64encode(<<-CLOUDINIT
    #cloud-config
    package_update: true
    packages: ${jsonencode(concat(local.common_packages, each.value.role == "db" ? local.db_packages : []))}
    runcmd: ${jsonencode(
      each.value.role == "master" ? [
        ["bash", "-c", "echo 'Master node ready' > /etc/motd"]
      ] : [
        ["bash", "-c", "curl -s https://downloads.apache.org/cassandra/KEYS | gpg --dearmor -o /usr/share/keyrings/cassandra-archive-keyring.gpg"],
        ["bash", "-c", "echo 'deb [signed-by=/usr/share/keyrings/cassandra-archive-keyring.gpg] https://debian.cassandra.apache.org 40x main' > /etc/apt/sources.list.d/cassandra.list"],
        ["apt-get", "update", "-qq"],
        ["apt-get", "install", "-y", "cassandra"],
        ["systemctl", "stop", "cassandra"],
        ["rm", "-rf", "/var/lib/cassandra/*"],
        ["update-alternatives", "--set", "java", "/usr/lib/jvm/java-11-openjdk-amd64/bin/java"],
        ["bash", "-c", "sed -i 's/seeds: .*/seeds: \"${local.seed_node_ip}\"/' /etc/cassandra/cassandra.yaml"],
        ["bash", "-c", "sed -i 's/listen_address: localhost/listen_address: ${each.value.ip}/' /etc/cassandra/cassandra.yaml"],
        ["bash", "-c", "sed -i 's/rpc_address: localhost/rpc_address: 0.0.0.0/' /etc/cassandra/cassandra.yaml"],
        ["bash", "-c", "sed -i 's/# broadcast_rpc_address: 1.2.3.4/broadcast_rpc_address: ${each.value.ip}/' /etc/cassandra/cassandra.yaml"],
        ["bash", "-c", "sed -i 's/endpoint_snitch: .*/endpoint_snitch: GossipingPropertyFileSnitch/' /etc/cassandra/cassandra.yaml"],
        ["systemctl", "enable", "cassandra"],
        ["systemctl", "start", "cassandra"]
      ]
    )}
    final_message: "cis-${each.value.role}-node ready"
  CLOUDINIT
  )

  tags = {
    project = var.project_name
    node    = each.key
    role    = each.value.role
    type    = each.value.is_seed ? "seed" : "standard"
  }
}
