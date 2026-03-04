output "vm_ip" {
  description = "Public IP address of the ephemeral VM"
  value       = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip
}

output "ssh_user" {
  description = "SSH user to connect to VM"
  value       = var.ssh_user
}

output "ssh_private_key" {
  description = "Generated private key used for SSH login"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

