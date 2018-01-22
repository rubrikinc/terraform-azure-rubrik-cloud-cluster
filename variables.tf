variable "azurerm_resource_group"   {}
variable "azurerm_location"         {}
variable "azurerm_rubrik_vhd_uri"   {}
variable "storage_acct_name"        {}
variable "storage_container"        {}
variable "azure_vm_size"            { default = "Standard_DS3_v2"}
variable "cluster_name"             { default = "rubrik-test-cluster" }
variable "cluster_size"             { default = 4 }
variable "subnet_id"                {}
variable "bootstrap_interface"      { default = "public" }
variable "subnet_snm"               {}
variable "subnet_gateway"           {}
# set our DNS and NTP servers
variable "ntp_servers"              {}
variable "dns_servers"              {}
# set the details of the admin account
variable "admin_email_address"      {}
variable "admin_password"           {}