terraform {
  required_providers {
    google = { }
  }
}

resource "google_container_cluster" "k8s_cluster" {
  name = var.k8s_cluster_name
  network = var.network_id
  subnetwork = var.subnetwork_id
  release_channel {
    channel = "RAPID"
  }
  min_master_version = "1.19.9-gke.100"
  node_version = "1.19.9-gke.100"
  remove_default_node_pool = true
  initial_node_count = var.initial_node_count

  dynamic "ip_allocation_policy" {
    for_each = var.cluster_secondary_range_name != "" && var.services_secondary_range_name != "" ? [1] : [0]
    content {
      cluster_secondary_range_name = var.cluster_secondary_range_name
      services_secondary_range_name = var.services_secondary_range_name
    }
  }
}

resource "google_container_node_pool" "k8s_node_pool" {
  name = "${var.k8s_cluster_name}-node-pool"
  cluster = google_container_cluster.k8s_cluster.name
  initial_node_count = var.initial_node_count
  autoscaling {
    min_node_count = var.min_nodes
    max_node_count = var.max_nodes
  }
  management {
    auto_repair = true
    auto_upgrade = true
  }
  node_config {
    preemptible = true
    machine_type = "n1-standard-2"
    disk_size_gb = 16
    disk_type = "pd-standard"
    service_account = var.node_sa
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

module "get_kubernetes_credentials" {
  source  = "terraform-google-modules/gcloud/google"
  additional_components = ["kubectl", "beta"]
  create_cmd_entrypoint  = "gcloud"
  create_cmd_body = "container clusters get-credentials ${google_container_cluster.k8s_cluster.name}"
  platform = "linux"
}
