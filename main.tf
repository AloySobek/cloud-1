terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

provider "google" {
  credentials = "/home/aloysobek/.config/gcloud/application_default_credentials.json"
  project = "cloud-1-310615"
  region = "europe-west3"
  zone = "europe-west3-a"
}

resource "google_compute_network" "cloud-1-network" {
  name = "cloud-1-network"
  description = "Main network for cloud-1 project"
  auto_create_subnetworks = false
  mtu = 1500
}

resource "google_compute_subnetwork" "cloud-1-subnetwork" {
  name = "cloud-1-subnetwork"
  network = google_compute_network.cloud-1-network.id
  ip_cidr_range = "10.0.0.0/16"
  description = "Main subnetwork for cloud-1 project"
}

resource "google_service_account" "cloud-1-service-account" {
  account_id = "cloud-1-service-account"
  display_name = "Service account"
  description = "Main service account for cloud-1 project"
}

resource "google_container_cluster" "cloud-1-cluster" {
  name = "cloud-1-cluster" 
  description = "Main cloud-1 cluster"

  network = google_compute_network.cloud-1-network.id
  subnetwork = google_compute_subnetwork.cloud-1-subnetwork.id

  min_master_version = "1.20"
  node_version = "1.20"

  remove_default_node_pool = true
  initial_node_count = 2
}

resource "google_container_node_pool" "cloud-1-node-pool" {
  name = "cloud-1-node-pool"

  cluster = google_container_cluster.cloud-1-cluster.id

  initial_node_count = 2

  autoscaling {
    min_node_count = 2
    max_node_count = 10
  }

  management {
    auto_repair = true
    auto_upgrade = true
  }

  node_config {
    preemptible = true
    machine_type = "n2-standard-2"
    disk_size_gb = 16
    disk_type = "pd-standard"
    service_account = google_service_account.cloud-1-service-account.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
