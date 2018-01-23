# Rubrik Cloud Cluster Terraform Configuration

## Overview

This repository contains the Rubrik CloudCluster Terraform provisioning configuration. This can be used to provision a Cloud Cluster in Azure.

## Requirements

Needs the Azure CLI to be installed and configured. This can be downloaded from [here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest), and configured using `az login` once installed.

## On using Public or Private IPs

There are two Terraform configurations present in the repository, these are designed to allow users to deploy Rubrik Cloud Clusters to Azure and bootstrap/manage instances via either public or private IP addresses.

It is not recommended to use public IP addresses as security then relies on the Network Security Group applied to the interfaces or subnet to restrict unwanted access to the Azure VMs, however this has been left in the repository, primarily for testing purposes.

If the deployment should use only private IPs then the computer applying the Terraform configuration should have HTTPS (port 443) access into the interfaces and subnet used. If this is not available then the bootstrap action will be unsuccessful.

In the case of using public IPs, just delete the `rk_cloudcluster_deploy.tf` file, and in the case of using private, delete the `rk_cloudcluster_deploy_public.tf` file.

## Repository Files

There are a number of files included in the repository, here we describe what each is for:

File Name | Description
--- | ---
`README.md` | The README file describing the repository and its usage
`rk_cloudcluster_deploy.tf` | The configuration used to deploy the Cloud Cluster if private interfaces are being used (see above)
`rk_cloudcluster_deploy_public.tf` | The configuration used to deploy the Cloud Cluster if public interfaces are being used (see above)
`variables.tf` | The variable definition file, this should not be altered
`terraform.tfvars.sample` | A sample variable file - can be used as the basis for creating your environment specific file

Before applying the configuration, a `terraform.tfvars` file should be created and added to this folder, a discussion on the content of this file can be found below.

## Creating the 'terraform.tfvars' file

The `terraform.tfvars` file is used to define the variables specific to your environment, and determines the configuration of the created resources. This file will need to be created and stored in the same directory as the other files provided here.

A sample `terraform.tfvars` file can be found in the repository with the name `terraform.tfvars.sample`.

The below describes the different variables which should be defined in this file:

Variable name | Description | Sample Value
--- | --- | ---
subnet_id | | "/subscriptions/fbc2ec27-abcd-1234-abcd-1af8b4feac31/resourceGroups/rubrik_resources/providers/Microsoft.Network/virtualNetworks/rubrik_network/subnets/rubrik_subnet"
storage_acct_name | The storage account to create the disks for the nodes in | "rubrikstorageacct"
storage_container | The container in above storage account to create the disks for the nodes in | "rubrik-cloudcluster"
subnet_snm | The subnet mask for the subnet configured in 'subnet_id' | "255.255.255.0"
subnet_gateway | The gateway IP for the subnet configured in 'subnet_id', this is the first IP in the range | "10.0.0.1"
cluster_size | The number of nodes to form in the Rubrik cluster, this can be 1, or 4+ | 4
cluster_name | The name to give the Rubrik cluster, also used for naming the node VMs | "rubrik-cloudcluster"
azurerm_resource_group | The ARM Resource Group to provision the cluster into | "rubrik_resources"
azurerm_location | The Azure location name to use for provisioning | "UK West"
azurerm_rubrik_vhd_uri | The URI for the Rubrik image copied to a blob store | "https://rubrikstorageacct.blob.core.windows.net/rubrik-images/rubrik-4-1-0-EA2-1804-osDisk.a48bc901-34a3-4662-8ca2-c4759027eb8c.vhd"
admin_password | The password to set for the admin account on the Rubrik cluster | "SuperSecretP@ssw0rd!"
admin_email_address | The email address to set for the admin account on the Rubrik cluster (can be changed later) | "admin@demo.com"
ntp_servers | The NTP server to configure on the Rubrik cluster (can be changed later), suggest that the sample value is used during bootstrap | "pool.ntp.org"
dns_servers | The DNS server(s) to configure on the Rubrik cluster (can be changed later), suggest that the sample value is used during bootstrap | "8.8.8.8\",\"8.8.4.4"


## Checking the status of the cluster bootstrap

The cluster bootstrap status can be checked using the `curl` command as follows:

```bash
curl -X GET --header 'Accept: application/json' 'https://<IP of bootstrap node>/api/internal/cluster/me/bootstrap?request_id=1' -k
```

This should return a JSON in this format:

```json
{
  "status": "IN_PROGRESS",
  "message": "",
  "ipConfig": "SUCCESS",
  "cassandraSetup": "SUCCESS",
  "installSchema": "IN_PROGRESS",
  "startServices": "NOT_STARTED",
  "ipmiConfig": "SUCCESS",
  "configAdminUser": "NOT_STARTED",
  "resetNodes": "NOT_STARTED",
  "setupDisks": "SUCCESS",
  "setupEncryptionAtRest": "NOT_STARTED",
  "setupRootDisks": "SUCCESS",
  "createTopLevelFilesystemDirs": "SUCCESS",
  "setupLoopDevices": "SUCCESS"
}
```

This can be monitored to completion. Once the `status` field is marked as `SUCCESS` the cluster is operational.