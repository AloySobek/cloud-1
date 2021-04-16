provider "google" {
  project = "cloud-1-310615"
  region = "europe-west3"
  zone = "europe-west3-a"	
}

# Bucket to store website media
resource "google_storage_bucket" "wp_media" {
  provider = google
  name     = "wp-website-media"
  location = "EU"
}

# Make new objects public
resource "google_storage_default_object_access_control" "wp_media_read" {
  bucket = google_storage_bucket.wp_media.name
  role   = "READER"
  entity = "allUsers"
}

resource "google_service_account" "wp_media_sa" {
  account_id   = "wp-media-sa"
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
