variable "dns_admin_sa_credentials_path" {
  type = string 
  description = "Path where dns-amin credentials stored"
}

variable "acme_email" {
  type = string
  description = "Email that will be used for acme certificate events"
}

variable "project_id" {
  type = string
  description = "Google cloud project id"
}

variable "dns_entry" {
  type = string
  description = "Domain name on which load balancer ip will be exposed"
}

variable "dns_zone_name" {
  type = string
  description = "Dns zone name where put the entry"
}
