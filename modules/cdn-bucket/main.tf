terraform {
  required_providers {
    google = { }
  }
}

resource "google_storage_bucket" "wp_media" {
  name = "wp-website-media"
  location = "EU"
  force_destroy = true
}

resource "google_compute_backend_bucket" "wp_bucket_backend" {
  name = "wp-bucket-backend"
  enable_cdn = true
  bucket_name = google_storage_bucket.wp_media.name
}

resource "google_storage_default_object_access_control" "wp_media_read" {
  bucket = google_storage_bucket.wp_media.name
  role   = "READER"
  entity = "allUsers"
}

resource "google_service_account" "wp_media_sa" {
  account_id = "wp-media-sa"
  display_name = "Wordpress media storage SA"
}

data "google_iam_policy" "wp_storage_admin" {
  binding {
    role = "roles/storage.admin"
    members = [
      "serviceAccount:${google_service_account.wp_media_sa.email}"
    ]
  }
}

resource "google_storage_bucket_iam_policy" "wp_bucket_policy" {
  bucket = google_storage_bucket.wp_media.name
  policy_data = data.google_iam_policy.wp_storage_admin.policy_data
}

module "get-service-account-credentials" {
  source  = "terraform-google-modules/gcloud/google"
  platform = "linux"
  create_cmd_entrypoint = "gcloud"
  create_cmd_body = "iam service-accounts keys create ${var.bucket_sa_credentials_path} --iam-account=${basename(google_service_account.wp_media_sa.name)}"
}

output "bucket_name" {
  value = google_storage_bucket.wp_media.name
}
