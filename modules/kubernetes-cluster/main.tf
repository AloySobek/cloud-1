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

resource "google_compute_network" "network" {
  name = "network"
  auto_create_subnetworks = false
  routing_mode = "GLOBAL"
  mtu = 1500
}

resource "google_compute_subnetwork" "subnetwork" {
  name = "subnetwork"
  ip_cidr_range = "10.10.0.0/16"
  network = google_compute_network.network.id
}

resource "google_dns_managed_zone" "dns-zone" {
  name = "dns-zone"
  dns_name = "${var.domain}."
  visibility = "public"
}

resource "google_compute_firewall" "allow-ssh" {
  name = "allow-ssh"
  network = google_compute_network.network.id
  priority = 65534
  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow-icmp" {
  name = "allow-icmp"
  network = google_compute_network.network.id
  priority = 65534
  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "allow-internal" {
  name    = "allow-internal"
  network = google_compute_network.network.id
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

resource "google_compute_firewall" "allow-external-443" {
  name    = "allow-external-443"
  network = google_compute_network.network.id
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_service_account" "service-account" {
  account_id = "service-account"
  display_name = "Service account"
}

resource "google_service_account_iam_member" "service-account-iam" {
  service_account_id = google_service_account.service-account.name
  member = "user:${var.sa_owner}"
  role = "roles/iam.serviceAccountUser"
}

resource "google_project_iam_member" "kubernetes-admin-role" {
  member = "serviceAccount:${google_service_account.service-account.email}"
  role = "roles/container.admin"
}

resource "google_project_iam_member" "dns-admin-role" {
  member = "serviceAccount:${google_service_account.service-account.email}"
  role = "roles/dns.admin"
}

resource "google_container_cluster" "kubernetes" {
  name = "kubernetes" 
  network = google_compute_network.network.id
  subnetwork = google_compute_subnetwork.subnetwork.id
  release_channel {
    channel = "RAPID"
  }
  min_master_version = "1.19.9-gke.100"
  node_version = "1.19.9-gke.100"
  remove_default_node_pool = true
  initial_node_count = 3
}

resource "google_container_node_pool" "kubernetes-node-pool" {
  name = "kubernetes-node-pool"
  cluster = google_container_cluster.kubernetes.name
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
    service_account = google_service_account.service-account.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

module "get-kubernetes-credentials" {
  source  = "terraform-google-modules/gcloud/google"
  additional_components = ["kubectl", "beta"]
  create_cmd_entrypoint  = "gcloud"
  create_cmd_body = "container clusters get-credentials ${google_container_cluster.kubernetes.name}"
  platform = "linux"
}

resource "kubernetes_namespace" "network" {
  metadata {
    name = "network"
  }
}

resource "helm_release" "cert-manager" {
  name = "cert-manager"
  namespace = "network"
  repository = "https://charts.jetstack.io"
  chart = "cert-manager"
  version = "1.3.0"
  set {
    name = "installCRDs"
    value = true
  }
}

resource "helm_release" "ingress-nginx" {
  name = "nginx-ingress-controller"
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
}

module "shell_execute" {
  source = "github.com/matti/terraform-shell-resource"
  command = "kubectl -n network get svc nginx-ingress-controller-ingress-nginx-controller -o json | jq .status.loadBalancer.ingress[0].ip | tr -d '\"'"
  depends_on = [helm_release.ingress-nginx]
}

resource "google_dns_record_set" "external-ip-dns-record" {
  name = "cloud-1.${var.domain}."
  managed_zone = google_dns_managed_zone.dns-zone.name
  rrdatas = [module.shell_execute.stdout]
  type = "A"
  ttl = 360
}

module "get-service-account-credentials" {
  source  = "terraform-google-modules/gcloud/google"
  platform = "linux"
  create_cmd_entrypoint = "gcloud"
  create_cmd_body = "iam service-accounts keys create ${var.sa_credentials_path} --iam-account=${basename(google_service_account.service-account.name)}"
}

resource "kubernetes_secret" "cloud-dns-secret" {
  metadata {
    name = "cloud-dns-secret"
    namespace = "network"
  }
  data = {
    "service-account.json" = "${file(var.sa_credentials_path)}" 
  }
  depends_on = [module.get-service-account-credentials]
}

resource "kubectl_manifest" "cluster-issuer" {
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
  depends_on = [kubernetes_secret.cloud-dns-secret, helm_release.cert-manager]
}
