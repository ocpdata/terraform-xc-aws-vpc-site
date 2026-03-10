output "site_name" {
  description = "Name of the configured Azure VNet Site."
  value       = volterra_azure_vnet_site.this.name
}

output "site_id" {
  description = "ID of the configured Azure VNet Site."
  value       = volterra_azure_vnet_site.this.id
}

output "master_public_ip_address" {
  description = "IP address of the master node."
  value       = try(local.output_map["master_public_ip_address"], null)
}

output "ssh_private_key" {
  description = "Azure VNet Site generated private key."
  value       = tls_private_key.key.private_key_openssh
  sensitive   = true
}

output "ssh_public_key" {
  description = "Azure VNet Site public key."
  value       = tls_private_key.key.public_key_openssh
}
