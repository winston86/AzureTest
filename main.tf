terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80" # Або інша версія, сумісна з ресурсами
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# VNet and Subnet
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-multiip-test"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-main"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes       = ["10.0.1.0/24"]
}

# NSG allowing SSH
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-ssh-only"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowOutboundInternet"
    priority                   = 101
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

# Primary Public IP
resource "azurerm_public_ip" "primary_ip" {
  name                = "pip-primary-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Dynamic Secondary Public IPs
resource "azurerm_public_ip" "secondary_ips" {
  count               = var.secondary_ip_count
  name                = "pip-secondary-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Interface (NIC)
resource "azurerm_network_interface" "nic" {
  name                = "nic-multiip-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.primary_ip.id
	primary                       = true
  }
  
  # Secondary IP Configurations (IP Aliases)
  dynamic "ip_configuration" {
    for_each = azurerm_public_ip.secondary_ips
    content {
      name                          = "secondary-${ip_configuration.key}"
      subnet_id                     = azurerm_subnet.subnet.id
      private_ip_address_allocation = "Static"
      # Assign private IPs starting from 10.0.1.100 + index
      private_ip_address            = cidrhost(azurerm_subnet.subnet.address_prefixes[0], 100 + ip_configuration.key)
      public_ip_address_id          = ip_configuration.value.id
	  primary                       = false
    }
  }

}

# Асоціація NIC з NSG (Обов'язково в нових версіях AzureRM)
resource "azurerm_network_interface_security_group_association" "nic_nsg_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Linux VM
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "vm-multiip-test"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = "Standard_B1s"
  admin_username        = var.vm_admin_username
  network_interface_ids = [azurerm_network_interface.nic.id]

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = var.public_key
  }
}