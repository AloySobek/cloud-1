terraform {
  required_providers {
    google = { }
  }
}

resource "google_compute_network" "network" {
  name = var.network_name
  auto_create_subnetworks = false
  routing_mode = "GLOBAL"
  mtu = 1500
}

resource "google_compute_subnetwork" "subnetwork" {
  name = var.subnetwork_name
  ip_cidr_range = var.subnetwork_ip_cidr_range
  network = google_compute_network.network.id

  dynamic "secondary_ip_range" {
    for_each = toset(var.subnetwork_secondary_ip_cidr_ranges)
    content {
      range_name = secondary_ip_range.key.name
      ip_cidr_range = secondary_ip_range.key.range
    }
  }
}

resource "google_compute_firewall" "allow_ssh" {
  name = "allow-ssh"
  network = google_compute_network.network.id
  priority = 65534
  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports = ["22"]
  }
}

resource "google_compute_firewall" "allow_icmp" {
  name = "allow-icmp"
  network = google_compute_network.network.id
  priority = 65534
  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.network.id
  allow {
    protocol = "tcp"
    ports = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["10.10.0.0/16"]
}

resource "google_compute_firewall" "allow_external_443" {
  name    = "allow-external-443"
  network = google_compute_network.network.id
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_dns_managed_zone" "dns_zone" {
  name = var.dns_zone_name
  dns_name = "${var.domain}."
  visibility = "public"
}
