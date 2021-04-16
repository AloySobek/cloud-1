module "kubernetes-cluster" {
  source = "./modules/kubernetes-cluster"

  sa_credentials_path = var.sa_credentials_path
  credentials_path = var.credentials_path
  project_id = var.project_id
  sa_owner = var.sa_owner
  domain = var.domain
  zone = var.zone
}
