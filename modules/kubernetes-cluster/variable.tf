variable "k8s_cluster_name" {
  type = string
  default = "k8s-cluster"
  description = "Name for kubernetes cluster"
}

variable "network_id" {
  type = string
  description = "Google network id"
}

variable "subnetwork_id" {
  type = string
  description = "Google subnetwork ip"
}

variable "initial_node_count" {
  type = number
  default = 3
  description = "Initial amount of nodes for kubernetes cluster"
}

variable "cluster_secondary_range_name" {
  type = string
  default = ""
  description = "Ip range for pods in secondary range of subnetwork"
}

variable "services_secondary_range_name" {
  type = string
  default = ""
  description = "Ip range for services in secondary range of subnetwork"
}

variable "min_nodes" {
  type = number
  default = 3
  description = "Autoscaling minimial amount of nodes"
}

variable "max_nodes" {
  type = number
  default = 5
  description = "Autoscaling maximum amount of nodes"
}

variable "node_sa" {
  type = string
  description = "Node's admin"
}
