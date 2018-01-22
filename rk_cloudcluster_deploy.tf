# Define the provider
provider "azurerm" {
  version = "~> 0.3"
}

# Get a public IP for our network interface - remove for prod
resource "azurerm_public_ip" "public_ip" {
  count                         = "${var.cluster_size}"
  name                          = "${var.cluster_name}${count.index + 1}_public_ip"
  location                      = "${var.azurerm_location}"
  resource_group_name           = "${var.azurerm_resource_group}"
  public_ip_address_allocation  = "dynamic"
}

# Build our network interfaces
resource "azurerm_network_interface" "cluster_interfaces" {
  count               = "${var.cluster_size}"
  name                = "${var.cluster_name}${count.index + 1}"
  location            = "${var.azurerm_location}"
  resource_group_name = "${var.azurerm_resource_group}"

  ip_configuration {
    name                          = "${var.cluster_name}${count.index + 1}"
    subnet_id                     = "${var.subnet_id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${element(azurerm_public_ip.public_ip.*.id, count.index)}"
  }
}

# Create managed disk for our OS disk from the VHD in our blob store
resource "azurerm_managed_disk" "os_disk" {
  count                 = "${var.cluster_size}"
  name                  = "${var.cluster_name}${count.index + 1}_os_0"
  location              = "${var.azurerm_location}"
  resource_group_name   = "${var.azurerm_resource_group}"
  storage_account_type  = "Standard_LRS"
  create_option         = "Import"
  os_type               = "Linux"
  source_uri            = "${var.azurerm_rubrik_vhd_uri}"
  disk_size_gb          = "400"
}

# Create our 3 x managed disks per node for data
resource "azurerm_managed_disk" "data_disk_1" {
  count                 = "${var.cluster_size}"
  name                  = "${var.cluster_name}${count.index + 1}_data_1"
  location              = "${var.azurerm_location}"
  resource_group_name   = "${var.azurerm_resource_group}"
  storage_account_type  = "Standard_LRS"
  create_option         = "Empty"
  disk_size_gb          = "1024"
}
resource "azurerm_managed_disk" "data_disk_2" {
  count                 = "${var.cluster_size}"
  name                  = "${var.cluster_name}${count.index + 1}_data_2"
  location              = "${var.azurerm_location}"
  resource_group_name   = "${var.azurerm_resource_group}"
  storage_account_type  = "Standard_LRS"
  create_option         = "Empty"
  disk_size_gb          = "1024"
}
resource "azurerm_managed_disk" "data_disk_3" {
  count                 = "${var.cluster_size}"
  name                  = "${var.cluster_name}${count.index + 1}_data_3"
  location              = "${var.azurerm_location}"
  resource_group_name   = "${var.azurerm_resource_group}"
  storage_account_type  = "Standard_LRS"
  create_option         = "Empty"
  disk_size_gb          = "1024"
}

# Create our production cluster
resource "azurerm_virtual_machine" "rubrik_cluster" {
  count                   = "${var.cluster_size}"
  name                    = "${var.cluster_name}${count.index + 1}"
  location                = "${var.azurerm_location}"
  resource_group_name     = "${var.azurerm_resource_group}"
  vm_size                 = "${var.azure_vm_size}"
  network_interface_ids   = ["${element(azurerm_network_interface.cluster_interfaces.*.id, count.index)}"]
  os_profile_linux_config { disable_password_authentication = false }
  # OS disk
  storage_os_disk {
    name              = "${element(azurerm_managed_disk.os_disk.*.name, count.index)}"
    managed_disk_id   = "${element(azurerm_managed_disk.os_disk.*.id, count.index)}"
    create_option     = "Attach"
    disk_size_gb      = "400"
    os_type           = "linux"
  }
  # 3 x capacity disks
  storage_data_disk {
    name              = "${element(azurerm_managed_disk.data_disk_1.*.name, count.index)}"
    managed_disk_id   = "${element(azurerm_managed_disk.data_disk_1.*.id, count.index)}"
    create_option     = "Attach"
    lun               = 0
    disk_size_gb      = "1024"
  }
  storage_data_disk {
    name              = "${element(azurerm_managed_disk.data_disk_2.*.name, count.index)}"
    managed_disk_id   = "${element(azurerm_managed_disk.data_disk_2.*.id, count.index)}"
    create_option     = "Attach"
    lun               = 1
    disk_size_gb      = "1024"
  }
  storage_data_disk {
    name              = "${element(azurerm_managed_disk.data_disk_3.*.name, count.index)}"
    managed_disk_id   = "${element(azurerm_managed_disk.data_disk_3.*.id, count.index)}"
    create_option     = "Attach"
    lun               = 2
    disk_size_gb      = "1024"
  }
}
/*
# Determine the gateway and subnet mask for our subnet, using built in functions
locals {
  subnet_mask = "${cidrnetmask("${data.aws_subnet.rubrik_cluster_subnet.cidr_block}")}"
  gateway_ip = "${cidrhost("${data.aws_subnet.rubrik_cluster_subnet.cidr_block}", 1)}"
}

# Generate our production host network config
data "template_file" "host_network" {
  count = "${var.cluster_size}"
  template = <<JSON
$${join(",",
  list(
    "$${jsonencode("netmask")}:$${jsonencode("${local.subnet_mask}")}",
    "$${jsonencode("gateway")}:$${jsonencode("${local.gateway_ip}")}",
    "$${jsonencode("address")}:$${jsonencode("${element(azurerm_network_interface.cluster_interfaces.*.private_ip_address, count.index)}")}",
  ))}"
JSON
}

data "template_file" "host_json" {
  count = "${var.cluster_size}"
  template = "$${jsonencode("${count.index}")}:{\"managementIpConfig\":{${element(data.template_file.host_network.*.rendered, count.index)}}}"
}

data "template_file" "all_host_json" {
  template = "{${join(",", data.template_file.host_json.*.rendered)}}"
}

# Build our production bootstrap JSON
data "template_file" "bootstrap_json" {
  template = "{\"dnsSearchDomains\":[],\"enableSoftwareEncryptionAtRest\":false,\"name\":\"${var.cluster_name}\",\"nodeConfigs\":${data.template_file.all_host_json.0.rendered},\"ntpServers\":[\"${var.ntp_servers}\"],\"dnsNameservers\":[\"${var.dns_servers}\"],\"adminUserInfo\":{\"password\":\"${var.admin_password}\",\"emailAddress\":\"${var.admin_email_address}\",\"id\":\"admin\"}}"
}

data "template_file" "bootstrap_json_normalised" {
  template = "${replace("${data.template_file.bootstrap_json.0.rendered}","\"\n","")}"
}

locals {
  bootstrap_ip = "${var.bootstrap_interface == "public" ? aws_instance.rubrik_cluster.0.public_ip : aws_instance.rubrik_cluster.0.private_ip}"
}

# Call the REST API on our production cluster to build the cluster. We wait 3 minutes for the API to be ready
resource "null_resource" "bootstrap" {
  provisioner "local-exec" {
    command = "sleep 180 && curl -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' -k -d '${data.template_file.bootstrap_json_normalised.rendered}' 'https://${local.bootstrap_ip}/api/internal/cluster/me/bootstrap'"
  }
}
*/