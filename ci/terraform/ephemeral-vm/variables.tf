variable "cloud_project" {
  description = "GCP project ID"
  type        = string
  default     = "app-runtime-platform-wg"
}

variable "cloud_region" {
  description = "GCP region"
  type        = string
  default     = "europe-west3"
}

variable "cloud_zone" {
  description = "GCP zone"
  type        = string
  default     = "europe-west3-a"
}

variable "cloud_credentials_json" {
  description = "Raw GCP service account JSON credentials"
  type        = string
  sensitive   = true
}

variable "name_prefix" {
  description = "Prefix for ephemeral VM resources"
  type        = string
  default     = "haproxy-ephemeral"
}

variable "machine_type" {
  description = "GCE machine type"
  type        = string
  default     = "t2d-standard-4"
}

variable "boot_image" {
  description = "Boot image for VM"
  type        = string
  default     = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts-amd64"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 60
}

variable "subnet_cidr" {
  description = "Subnet CIDR for ephemeral network"
  type        = string
  default     = "10.99.0.0/24"
}

variable "ssh_user" {
  description = "SSH username for VM login"
  type        = string
  default     = "ubuntu"
}

variable "ssh_source_ranges" {
  description = "CIDRs allowed to SSH into ephemeral VM"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "service_account_email" {
  description = "Service account email attached to VM"
  type        = string
  default     = "default"
}

variable "service_account_scopes" {
  description = "OAuth scopes for attached service account"
  type        = list(string)
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}
