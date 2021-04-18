terraform {
  backend "gcs" {
    bucket  = "cloud-1-terraform-state"
    prefix  = "terraform/state"
  }
}

module "kubernetes-cluster" {
  source = "./modules/kubernetes-cluster"

  sa_credentials_path = var.sa_credentials_path
  credentials_path = var.credentials_path
  project_id = var.project_id
  sa_owner = var.sa_owner
  domain = var.domain
  zone = var.zone
}

module "cdn-bucket" {
  source = "./modules/cdn-bucket"

  bucket_sa_credentials_path = var.bucket_sa_credentials_path
  credentials_path = var.credentials_path
  project_id = var.project_id
  zone = var.zone
}

module "mysql" {
  source = "./modules/mysql"
}

# module "wordpress" {
#   source = "./modules/wordpress"
#   bucket_name = module.cdn-bucket.bucket_name
#   bucket_sa_credentials_path = var.bucket_sa_credentials_path
# }
