terraform {
  backend "gcs" {
    bucket  = "cloud-1-terraform-state"
    prefix  = "terraform/state"
  }
  required_providers {
    kubernetes-alpha = { source = "hashicorp/kubernetes-alpha" }
    kubernetes       = { source = "hashicorp/kubernetes" }
    kubectl          = { source = "gavinbunney/kubectl" }
    google           = { source = "hashicorp/google" }
    helm             = { source = "hashicorp/helm" }
  }
}

provider "kubernetes-alpha" { config_path = "~/.kube/config" }
provider "kubernetes"       { config_path = "~/.kube/config" }
provider "kubectl"          { config_path = "~/.kube/config" }
provider "google"           { alias = "token" }
provider "helm" {
  kubernetes { config_path = "~/.kube/config" }
}

data "google_service_account_access_token" "sa" {
  provider = google.token
  target_service_account = "terraform-admin@cloud-1-310615.iam.gserviceaccount.com"
  lifetime = "2400s"
  scopes = ["https://www.googleapis.com/auth/cloud-platform"]
}

provider "google" {
  access_token = data.google_service_account_access_token.sa.access_token
  project = var.project_id
  region = var.region
  zone = var.zone
}

module "network" {
  source = "./modules/google-network"
  network_name = "cloud-1-network"
  subnetwork_name = "cloud-1-subnetwork"
  subnetwork_ip_cidr_range = "10.0.0.0/16"
  subnetwork_secondary_ip_cidr_ranges = [
    {
      name = "pods"
      range = "10.1.0.0/20"
    },
    {
      name = "services"
      range = "10.2.0.0/24"
    }
  ]
  dns_zone_name = "cloud-1-dns-zone"
  domain = "starquark.com"
}

module "kubernetes_cluster" {
  source = "./modules/kubernetes-cluster"
  k8s_cluster_name = "cloud-1-k8s-cluster"
  network_id = module.network.network_id
  subnetwork_id = module.network.subnetwork_id
  cluster_secondary_range_name = "pods"
  services_secondary_range_name = "services"
  initial_node_count = 3
  min_nodes = 3
  max_nodes = 5
  node_sa = "terraform-admin@cloud-1-310615.iam.gserviceaccount.com"
}

module "kubernetes_setup" {
  source = "./modules/kubernetes-setup/"
  dns_admin_sa_credentials_path = "~/.config/gcloud/dns-admin.json"
  acme_email = "super.rustamm@gmail.com"
  project_id = var.project_id
  dns_entry = "cloud-1-nginx.starquark.com"
  dns_zone_name = "cloud-1-dns-zone"
  depends_on = [module.kubernetes_cluster]
}

module "shell_execute" {
  source = "github.com/matti/terraform-shell-resource"
  command = "gcloud compute instances list | sed -n '2p' | awk '{print $1}'"
  depends_on = [module.kubernetes_cluster]
}

module "nfs" {
  source = "./modules/nfs"
  hostname = module.shell_execute.stdout
}

module "mysql" {
  source = "./modules/mysql"
  mysql_replication_password = var.mysql_replication_password
  mysql_root_password = var.mysql_root_password
  mysql_password = var.mysql_password
  depends_on = [module.kubernetes_cluster]
}

module "wordpress" {
  source = "./modules/wordpress"
  wordpress_password = var.wordpress_password
  mysql_password = var.mysql_password
  depends_on = [module.mysql, module.nfs]
}
