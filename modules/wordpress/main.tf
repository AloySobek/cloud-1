terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "kubectl" {
  config_path = "~/.kube/config"
}

resource "kubernetes_service" "wordpress-service" {
  metadata {
    name = "wordpress-service"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    type = "NodePort"

    selector = {
      app = "wordpress"
      tier = "frontend"
    }
    port {
      port = 80
      target_port = 80
    }
  }
}

resource "kubernetes_persistent_volume_claim" "wordpress-pvc" {
  metadata {
    name = "wordpress-pvc"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "32Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "wordpress-deployment" {
  metadata {
    name = "wordpress-deployment"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "wordpress"  
        tier = "frontend"
      }
    }
    template {
      metadata {
        labels = {
          app = "wordpress"
          tier = "frontend"
        }
      }
      spec {
        container {
          name = "wordpress-container"
          image = "wordpress:4.8-apache"
          env {
            name = "WORDPRESS_DB_HOST"
            value = "mysql-service"
          }
          env {
            name = "WORDPRESS_DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = "mysql-credentials-secret"
                key = "root-password"
              }
            }
          }
          port {
            container_port = 80
          }
          volume_mount {
            name = "wordpress-pv"
            mount_path = "/var/www/html"
          }
        }
        volume {
          name = "wordpress-pv"
          persistent_volume_claim {
            claim_name = "wordpress-pvc"
          }
        }
      }
    }
  }
}

resource "kubectl_manifest" "wordpress-certificate" {
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wordpress-certificate
  labels:
    app: wordpress
    tier: frontend
spec:
  commonName: "cloud-1.starquark.com"
  dnsNames: ["cloud-1.starquark.com"]
  secretName: cloud-1.starquark.com
  issuerRef:
    name: cluster-issuer
    kind: ClusterIssuer
    group: cert-manager.io
YAML
}
