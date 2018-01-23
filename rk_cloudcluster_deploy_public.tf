# Define the provider
provider "azurerm" {
  version = "~> 0.3"
}

# Get a public IP for our network interface
resource "azurerm_public_ip" "public_ip" {
  count                         = "${var.cluster_size}"
  name                          = "${var.cluster_name}${count.index + 1}_public_ip"
  location                      = "${var.azurerm_location}"
  resource_group_name           = "${var.azurerm_resource_group}"
  public_ip_address_allocation  = "static"
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

# Create our production cluster
resource "azurerm_virtual_machine" "rubrik_cluster" {
  count                   = "${var.cluster_size}"
  name                    = "${var.cluster_name}${count.index + 1}"
  location                = "${var.azurerm_location}"
  resource_group_name     = "${var.azurerm_resource_group}"
  vm_size                 = "${var.azure_vm_size}"
  # Delete our disks when we terminate the instance
  delete_os_disk_on_termination     = true
  delete_data_disks_on_termination  = true
  network_interface_ids   = ["${element(azurerm_network_interface.cluster_interfaces.*.id, count.index)}"]
  os_profile_linux_config { disable_password_authentication = false }
  os_profile {
    computer_name  = "${var.cluster_name}${count.index + 1}"
    admin_username = "ubuntu"
    admin_password = "N0tAPassw0rd!@"
  }
  # OS disk
  storage_os_disk {
    name              = "${var.cluster_name}${count.index + 1}_os_0.vhd"
    image_uri         = "${var.azurerm_rubrik_vhd_uri}"
    vhd_uri           = "https://${var.storage_acct_name}.blob.core.windows.net/${var.storage_container}/${var.cluster_name}${count.index + 1}_os_0.vhd"
    create_option     = "FromImage"
    caching           = "ReadWrite"
    disk_size_gb      = "400"
    os_type           = "linux"
  }
  # 3 x capacity disks
  storage_data_disk {
    name              = "${var.cluster_name}${count.index + 1}_data_1.vhd"
    vhd_uri           = "https://${var.storage_acct_name}.blob.core.windows.net/${var.storage_container}/${var.cluster_name}${count.index + 1}_data_1.vhd"
    create_option     = "Empty"
    caching           = "ReadWrite"
    lun               = 0
    disk_size_gb      = "1024"
  }
  storage_data_disk {
    name              = "${var.cluster_name}${count.index + 1}_data_2.vhd"
    vhd_uri           = "https://${var.storage_acct_name}.blob.core.windows.net/${var.storage_container}/${var.cluster_name}${count.index + 1}_data_2.vhd"
    create_option     = "Empty"
    caching           = "ReadWrite"
    lun               = 1
    disk_size_gb      = "1024"
  }
  storage_data_disk {
    name              = "${var.cluster_name}${count.index + 1}_data_3.vhd"
    vhd_uri           = "https://${var.storage_acct_name}.blob.core.windows.net/${var.storage_container}/${var.cluster_name}${count.index + 1}_data_3.vhd"
    create_option     = "Empty"
    caching           = "ReadWrite"
    lun               = 2
    disk_size_gb      = "1024"
  }
  depends_on = [
    "azurerm_public_ip.public_ip",
    "azurerm_network_interface.cluster_interfaces"
    ]
}

# Generate our production host network config
data "template_file" "host_network" {
  count = "${var.cluster_size}"
  template = <<JSON
$${join(",",
  list(
    "$${jsonencode("netmask")}:$${jsonencode("${var.subnet_snm}")}",
    "$${jsonencode("gateway")}:$${jsonencode("${var.subnet_gateway}")}",
    "$${jsonencode("address")}:$${jsonencode("${element(azurerm_network_interface.cluster_interfaces.*.private_ip_address, count.index)}")}",
  ))}"
JSON
  depends_on = ["azurerm_virtual_machine.rubrik_cluster"]
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

# Call the REST API on our production cluster to build the cluster. We wait 3 minutes for the API to be ready
resource "null_resource" "bootstrap" {
  provisioner "local-exec" {
    command = "sleep 180 && curl -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' -k -d '${data.template_file.bootstrap_json_normalised.rendered}' 'https://${azurerm_public_ip.public_ip.0.ip_address}/api/internal/cluster/me/bootstrap'"
  }
}
