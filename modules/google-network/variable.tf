variable "network_name" {
  type = string
  default = "network"
  description  = "Name for google network"
}

variable "subnetwork_name" {
  type = string
  default = "subnetwork"
  description  = "Name for google subnetwork"
}

variable "subnetwork_ip_cidr_range" {
  type = string
  default = "10.0.0.0/16"
  description  = "Cidr ip range for google subnetwork"
}

variable "subnetwork_secondary_ip_cidr_ranges" {
  type = list(object({
    name = string
    range = string
  }))
  default = []
  description  = "Cidr ip range for google subnetwork"
}

variable "dns_zone_name" {
  type = string
  default = "dns-zone"
  description = "Google dns zone name"
}

variable "domain" {
  type = string
  default = "example.com"
  description = "Domain name for dns managed zone"
}
