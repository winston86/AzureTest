variable "secondary_ip_count" {
  description = "Number of secondary public IP configurations to create (beyond the primary one)."
  type        = number
  default     = 2 # 5 for testing as per task requirements
}

variable "location" {
  description = "The Azure region where resources will be created."
  type        = string
  default     = "East US"
}

variable "vm_admin_username" {
  description = "Username for the VM administrator."
  type        = string
  default     = "azureadmin"
}

variable "public_key" {
  description = "Public key for SSH access to the VM."
  type        = string
  # IMPORTANT: Replace with your actual SSH public key content (e.g., file("~/.ssh/id_rsa.pub"))
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC2..." 
}

variable "resource_group_name" {
  description = "Name for the resource group."
  type        = string
  default     = "rg-devops-multiip-test"
}