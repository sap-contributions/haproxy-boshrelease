terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "google" {
  project     = var.cloud_project
  region      = var.cloud_region
  zone        = var.cloud_zone
  credentials = var.cloud_credentials_json
}

resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  vm_name = "${var.name_prefix}-${random_id.suffix.hex}"
}

resource "google_compute_network" "ephemeral" {
  name                    = "${local.vm_name}-net"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "ephemeral" {
  name          = "${local.vm_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.cloud_region
  network       = google_compute_network.ephemeral.id
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${local.vm_name}-allow-ssh"
  network = google_compute_network.ephemeral.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = ["ephemeral-vm-ssh"]
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "google_compute_instance" "vm" {
  name         = local.vm_name
  machine_type = var.machine_type
  zone         = var.cloud_zone
  tags         = ["ephemeral-vm-ssh"]

  boot_disk {
    initialize_params {
      image = var.boot_image
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.ephemeral.id
    access_config {}
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${trimspace(tls_private_key.ssh.public_key_openssh)}"
  }

  scheduling {
    automatic_restart   = false
    on_host_maintenance = "MIGRATE"
    preemptible         = false
  }

  service_account {
    email  = var.service_account_email
    scopes = var.service_account_scopes
  }

  labels = {
    created_by = "concourse"
    purpose    = "acceptance-tests-ephemeral-vm"
  }
}

