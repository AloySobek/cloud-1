terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes" }
    kubectl    = { source  = "gavinbunney/kubectl" }
  }
}

resource "kubernetes_ingress" "wordpress_ingress" {
  metadata {
    name = "wordpress-ingress"
    annotations = {
      "kubernetes.io/tls-acme" = "true"
      "kubernetes.io/ingress.class" = "nginx"
    }
  }
  spec {
    tls {
      hosts = ["cloud-1.starquark.com"]
      secret_name = "cloud-1.starquark.com"
    }
    rule {
      host = "cloud-1.starquark.com"
      http {
        path {
          path = "/"
          backend {
            service_name = "wordpress"
            service_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_secret" "wordpress_password" {
  metadata {
    name = "wordpress-password"
  }
  data = {
    "wordpress-password" = "${var.wordpress_password}"
  }
}

resource "helm_release" "wordpress" {
  name = "wordpress"
  repository = "https://charts.bitnami.com/bitnami"
  chart = "wordpress"
  values = [
<<YAML
commonLabels:
  app: wordpress
  tier: frontend
  service: wordpress
wordpressUsername: wordpress
existingSecret: wordpress-password
wordpressEmail: example@example.com
wordpressFirstName: Bill
wordpressLastName: Gates
wordpressBlogName: Blog
wordpressTablePrefix: wp_
wordpressScheme: http
service:
  type: ClusterIP
persistence:
  storageClass: nfs
  size: 16Gi
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPU: 50
  targetMemory: 50
mariadb:
  enabled: false
externalDatabase:
  host: mysql-primary.storage
  port: 3306
  user: wordpress
  password: ${var.mysql_password}
  database: wordpress
YAML
  ]
}
