output "network_id" {
  value = google_compute_network.network.id
  description = "Google network id"
}

output "subnetwork_id" {
  value = google_compute_subnetwork.subnetwork.id
  description = "Google subnetwork id"
}
