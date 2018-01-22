variable "azurerm_resource_group" {}
variable "azurerm_location"       {}
variable "azurerm_rubrik_vhd_uri" {}
variable "azure_vm_size"          { default = "Standard_DS3_v2"}
variable "cluster_name"           { default = "rubrik-test-cluster" }
variable "cluster_size"           { default = 4 }
variable "subnet_id"              {}
# set our DNS and NTP servers
variable "ntp_servers"            {}
variable "dns_servers"            {}
# set the details of the admin account
variable "admin_email_address"    {}
variable "admin_password"         {}