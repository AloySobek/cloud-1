terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes" }
    kubectl    = { source = "gavinbunney/kubectl" }
    google     = { source = "hashicorp/google" }
    helm       = { source = "hashicorp/helm" }
  }
}

provider "google" {
  credentials = var.credentials_path
  project = var.project_id
  region = join("-", [split("-", var.zone)[0], split("-", var.zone)[1]])
  zone = var.zone
}

provider "kubernetes" { config_path = "~/.kube/config" }
provider "kubectl" { config_path = "~/.kube/config" }
provider "helm" {
  kubernetes { config_path = "~/.kube/config" }
}

resource "google_compute_network" "cloud_1_network" {
  name = "cloud-1-network"
  auto_create_subnetworks = false
  routing_mode = "GLOBAL"
  mtu = 1500
}

resource "google_compute_subnetwork" "cloud_1_subnetwork" {
  name = "cloud-1-subnetwork"
  ip_cidr_range = "10.10.0.0/16"
  network = google_compute_network.cloud_1_network.id
}

resource "google_dns_managed_zone" "cloud_1_dns_zone" {
  name = "cloud-1-dns-zone"
  dns_name = "${var.domain}."
  visibility = "public"
}

resource "google_compute_firewall" "allow_ssh" {
  name = "allow-ssh"
  network = google_compute_network.cloud_1_network.id
  priority = 65534
  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow_icmp" {
  name = "allow-icmp"
  network = google_compute_network.cloud_1_network.id
  priority = 65534
  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.cloud_1_network.id
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["10.10.0.0/16"]
}

resource "google_compute_firewall" "allow_external_443" {
  name    = "allow-external-443"
  network = google_compute_network.cloud_1_network.id
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_service_account" "cloud_1_admin" {
  account_id = "cloud-1-admin"
  display_name = "Service account"
}

resource "google_service_account_iam_member" "cloud_1_sa_owner" {
  service_account_id = google_service_account.cloud_1_admin.name
  member = "user:${var.sa_owner}"
  role = "roles/iam.serviceAccountUser"
}

resource "google_project_iam_member" "cloud_1_kubernetes_admin" {
  member = "serviceAccount:${google_service_account.cloud_1_admin.email}"
  role = "roles/container.admin"
}

resource "google_project_iam_member" "cloud_1_dns_admin" {
  member = "serviceAccount:${google_service_account.cloud_1_admin.email}"
  role = "roles/dns.admin"
}

resource "google_container_cluster" "cloud_1_kubernetes_cluster" {
  name = "cloud-1-kubernetes-cluster" 
  network = google_compute_network.cloud_1_network.id
  subnetwork = google_compute_subnetwork.cloud_1_subnetwork.id
  release_channel {
    channel = "RAPID"
  }
  min_master_version = "1.19.9-gke.100"
  node_version = "1.19.9-gke.100"
  remove_default_node_pool = true
  initial_node_count = 3
}

resource "google_container_node_pool" "cloud_1_node_pool" {
  name = "cloud-1-node-pool"
  cluster = google_container_cluster.cloud_1_kubernetes_cluster.name
  initial_node_count = 3
  autoscaling {
    min_node_count = 2
    max_node_count = 5
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
    service_account = google_service_account.cloud_1_admin.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

module "get_kubernetes_credentials" {
  source  = "terraform-google-modules/gcloud/google"
  additional_components = ["kubectl", "beta"]
  create_cmd_entrypoint  = "gcloud"
  create_cmd_body = "container clusters get-credentials ${google_container_cluster.cloud_1_kubernetes_cluster.name}"
  platform = "linux"
}

resource "kubernetes_namespace" "network" {
  metadata {
    name = "network"
  }
  depends_on = [google_container_cluster.cloud_1_kubernetes_cluster]
}

resource "helm_release" "cert_manager" {
  name = "cert-manager"
  namespace = "network"
  repository = "https://charts.jetstack.io"
  chart = "cert-manager"
  version = "1.3.0"
  set {
    name = "installCRDs"
    value = true
  }
  depends_on = [google_container_cluster.cloud_1_kubernetes_cluster, kubernetes_namespace.network]
}

resource "helm_release" "ingress_nginx" {
  name = "ingress-nginx-controller"
  namespace = "network"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart = "ingress-nginx"
  set { 
    name = "controller.replicaCount"
    value = 3
  }
  set {
    name = "controller.minAvailable"
    value = 2
  }
  set {
    name  = "controller.metrics.enabled"
    value = true
  }
  depends_on = [google_container_cluster.cloud_1_kubernetes_cluster, kubernetes_namespace.network]
}

module "shell_execute" {
  source = "github.com/matti/terraform-shell-resource"
  command = "kubectl -n network get svc ingress-nginx-controller-controller -o json | jq .status.loadBalancer.ingress[0].ip | tr -d '\"'"
  depends_on = [helm_release.ingress_nginx]
}

resource "google_dns_record_set" "cloud_1_external_ip_dns_record" {
  name = "${var.domain}."
  managed_zone = google_dns_managed_zone.cloud_1_dns_zone.name
  rrdatas = [module.shell_execute.stdout]
  type = "A"
  ttl = 360
}

module "get_service_account_credentials" {
  source  = "terraform-google-modules/gcloud/google"
  platform = "linux"
  create_cmd_entrypoint = "gcloud"
  create_cmd_body = "iam service-accounts keys create ${var.sa_credentials_path} --iam-account=${basename(google_service_account.cloud_1_admin.name)}"
}

resource "kubernetes_secret" "cloud_1_dns_secret" {
  metadata {
    name = "cloud-dns-credentials"
    namespace = "network"
  }
  data = {
    "service-account.json" = "${file(var.sa_credentials_path)}" 
  }
  depends_on = [google_container_cluster.cloud_1_kubernetes_cluster, module.get_service_account_credentials]
}

resource "kubectl_manifest" "cloud_1_cluster_issuer" {
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: cluster-issuer
spec:
  acme:
    email: ${var.sa_owner}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: issuer-account-key
    solvers:
      - dns01:
          cloudDNS:
            project: ${var.project_id}
            serviceAccountSecretRef:
              name: cloud-dns-secret
              key: service-account.json
YAML
  depends_on = [kubernetes_secret.cloud_1_dns_secret, helm_release.cert_manager]
}
