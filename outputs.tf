output "vm_admin_username" {
  description = "Admin username for the VM."
  value       = var.vm_admin_username
}

output "primary_public_ip" {
  description = "The primary public IP address of the VM."
  value       = azurerm_public_ip.primary_ip.ip_address
}

output "all_public_ips" {
  description = "List of all public IPs attached to the VM (Primary + Secondaries)."
  value = concat(
    [azurerm_public_ip.primary_ip.ip_address],
    [for ip in azurerm_public_ip.secondary_ips : ip.ip_address]
  )
}

output "all_private_ips" {
  description = "List of all private IPs attached to the VM (Primary + Secondaries)."
  value = concat(
    [azurerm_network_interface.nic.ip_configuration[0].private_ip_address],
    [for config in azurerm_network_interface.nic.ip_configuration : config.private_ip_address if config.name != "primary"]
  )
}

output "nic_name" {
  description = "The name of the Network Interface Card."
  value       = azurerm_network_interface.nic.name
}