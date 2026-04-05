# =============================================================================
# vms.tf — Public IPs, NICs, and Linux VMs for the 3-node Cassandra cluster
# =============================================================================

# ---------------------------------------------------------------------------
# cloud-init script (base64-encoded) — runs once at first boot
# Installs: OpenJDK 11, Python 3.10, Apache Cassandra 4.0
# Cassandra is installed via the official Apache apt repo so version is fixed.
# ---------------------------------------------------------------------------
locals {
  cloud_init_script = base64encode(<<-CLOUDINIT
    #cloud-config
    package_update: true
    package_upgrade: false

    packages:
      - apt-transport-https
      - gnupg
      - curl
      - python3.10
      - python3-pip
      - openjdk-11-jdk

    runcmd:
      # ---- Cassandra 4.0 apt repo ----
      - curl -s https://downloads.apache.org/cassandra/KEYS | gpg --dearmor -o /etc/apt/trusted.gpg.d/cassandra.gpg
      - echo "deb https://debian.cassandra.apache.org 40x main" > /etc/apt/sources.list.d/cassandra.sources.list
      - apt-get update -qq
      - apt-get install -y cassandra
      # ---- Ensure Java 11 is the active JDK ----
      - update-alternatives --set java /usr/lib/jvm/java-11-openjdk-arm64/bin/java
      # ---- Configure cassandra.yaml (Member 1 Automation) ----
      - sed -i "s/cluster_name: 'Test Cluster'/cluster_name: 'CIS Cassandra Cluster'/" /etc/cassandra/cassandra.yaml
      - sed -i 's/seeds: "127.0.0.1"/seeds: "10.0.1.11"/' /etc/cassandra/cassandra.yaml
      - sed -i "s/listen_address: localhost/listen_address: $(hostname -I | awk '{print $1}')/" /etc/cassandra/cassandra.yaml
      - sed -i "s/rpc_address: localhost/rpc_address: 0.0.0.0/" /etc/cassandra/cassandra.yaml
      - sed -i "s/endpoint_snitch: SimpleSnitch/endpoint_snitch: GossipingPropertyFileSnitch/" /etc/cassandra/cassandra.yaml
      # ---- Enable and Start Cassandra ----
      - systemctl enable cassandra
      - systemctl start cassandra

    final_message: "cis-cassandra node ready after $UPTIME seconds"
  CLOUDINIT
  )
}

# ---------------------------------------------------------------------------
# Public IPs — one per node; allow SSH from the internet
# Static allocation prevents the IP changing after a stop/start
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "node" {
  for_each = local.nodes

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
    private_ip_address            = each.value.ip   # 10.0.1.11 / .12 / .13
    public_ip_address_id          = azurerm_public_ip.node[each.key].id
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
# Password auth is explicitly disabled; SSH key is the only access method.
# ---------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "node" {
  for_each = local.nodes

  name                = "${var.project_name}-${each.key}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.vm_size

  # Admin account — password auth disabled, key-only
  admin_username                  = "cassandra"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "cassandra"
    public_key = file(var.ssh_public_key_path)
  }

  # Attach the NIC with the static private IP
  network_interface_ids = [azurerm_network_interface.node[each.key].id]

  # OS disk — standard SSD is sufficient for a dev cluster
  os_disk {
    name                 = "${var.project_name}-${each.key}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  # Ubuntu 22.04 LTS from Canonical
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-arm64"
    version   = "latest"
  }

  # cloud-init: installs JDK 11, Python 3.10, Cassandra 4.0 on first boot
  custom_data = local.cloud_init_script

  tags = {
    project = var.project_name
    node    = each.key
    role    = each.value.is_seed ? "seed" : "non-seed"
  }
}
