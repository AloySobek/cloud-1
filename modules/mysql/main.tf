terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_secret" "mysql-credentials-secret" {
  metadata {
    name = "mysql-credentials-secret"
    labels = {
      app = "wordpress"
    }
  }
  data = {
    "root-password" = var.mysql_root_password
  }
}

resource "kubernetes_service" "mysql-service" {
  metadata {
    name = "mysql-service"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    selector = {
      app = "wordpress"
    }
    port {
      port = 3306
      target_port = 3306
    }
  }
}

resource "kubernetes_persistent_volume_claim" "mysql-pvc" {
  metadata {
    name = "mysql-pvc"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "16Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "mysql-deployment" {
  metadata {
    name = "mysql-deployment"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "wordpress"  
      }
    }
    template {
      metadata {
        labels = {
          app = "wordpress"
        }
      }
      spec {
        container {
          name = "mysql-container"
          image = "mysql:5.6"
          env {
            name = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = "mysql-credentials-secret"
                key = "root-password"
              }
            }
          }
          port {
            container_port = 3306
          }
          volume_mount {
            name = "mysql-pv"
            mount_path = "/var/lib/mysql"
          }
        }
        volume {
          name = "mysql-pv"
          persistent_volume_claim {
            claim_name = "mysql-pvc"
          }
        }
      }
    }
  }
}
