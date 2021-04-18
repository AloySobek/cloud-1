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

# resource "kubernetes_secret" "wordpress-sa-secret" {
#   metadata {
#     name = "wordpress-sa-secret"
#   }
#   data = {
#     "service-account.json" = "${file(var.bucket_sa_credentials_path)}"
#   }
# }

# resource "kubectl_manifest" "wordpress-certificate" {
#   yaml_body = <<YAML
# apiVersion: cert-manager.io/v1
# kind: Certificate
# metadata:
#   name: wordpress-certificate
#   labels:
#     app: wordpress
#     tier: frontend
# spec:
#   commonName: "cloud-1.starquark.com"
#   dnsNames: ["cloud-1.starquark.com"]
#   secretName: cloud-1.starquark.com
#   issuerRef:
#     name: cluster-issuer
#     kind: ClusterIssuer
#     group: cert-manager.io
# YAML
# }

# resource "kubernetes_ingress" "wordpress-ingress" {
#   metadata {
#     name = "wordpress-ingress"
#     annotations = {
#       "kubernetes.io/ingress.class" = "nginx"
#     }
#   }

#   spec {
#     tls {
#       hosts = ["cloud-1.starquark.com"]
#       secret_name = "cloud-1.starquark.com"
#     }
#     rule {
#       host = "cloud-1.starquark.com"
#       http {
#         path {
#           path = "/"
#           backend {
#             service_name = "wordpress-service"
#             service_port = 80
#           }
#         }
#       }
#     }
#   }
# }

# resource "kubernetes_service" "wordpress-service" {
#   metadata {
#     name = "wordpress-service"
#     labels = {
#       app = "wordpress"
#     }
#   }
#   spec {
#     selector = {
#       app = "wordpress"
#       tier = "frontend"
#     }
#     port {
#       port = 80
#       target_port = 80
#     }
#   }
# }

# resource "kubernetes_persistent_volume_claim" "wordpress-pvc" {
#   metadata {
#     name = "wordpress-pvc"
#     labels = {
#       app = "wordpress"
#     }
#   }
#   spec {
#     access_modes = ["ReadWriteOnce"]
#     resources {
#       requests = {
#         storage = "32Gi"
#       }
#     }
#   }
# }

# resource "kubernetes_deployment" "wordpress-deployment" {
#   metadata {
#     name = "wordpress-deployment"
#     labels = {
#       app = "wordpress"
#     }
#   }
#   spec {
#     selector {
#       match_labels = {
#         app = "wordpress"  
#         tier = "frontend"
#       }
#     }
#     template {
#       metadata {
#         labels = {
#           app = "wordpress"
#           tier = "frontend"
#         }
#       }
#       spec {
#         init_container {
#           security_context {
#             run_as_user = 0
#           }
#           name = "wordpress-cli-container-0"
#           image = "wordpress:cli"
#           command = ["wp", "--allow-root", "core", "download", "--force", "--path=/var/www/html"]
#           volume_mount {
#             name = "wordpress-pv"
#             mount_path = "/var/www/html"
#           }
#         }
#         init_container {
#           security_context {
#             run_as_user = 0
#           }
#           name = "wordpress-cli-container-0-1"
#           image = "wordpress:cli"
#           command = ["wp", "--allow-root", "config", "create", "--dbhost=mysql-service", "--dbuser=wordpress", "--dbpass=wordpress", "--dbname=wordpress", "--force", "--path=/var/www/html"]
#           volume_mount {
#             name = "wordpress-pv"
#             mount_path = "/var/www/html"
#           }
#         }
#         init_container {
#           security_context {
#             run_as_user = 0
#           }
#           name = "wordpress-cli-container-1"
#           image = "wordpress:cli"
#           command = [
#             "wp", "--allow-root", "core", "install", "--path=/var/www/html",
#             "--url=https://cloud-1.starquark.com", "--title=cloud-1",
#             "--admin_user=root", "--admin_password=gpr1CL1ty3qCln5",
#             "--admin_email=example@example.com", "--skip-email",
#           ]
#           volume_mount {
#             name = "wordpress-pv"
#             mount_path = "/var/www/html"
#           }
#         }
#         init_container {
#           security_context {
#             run_as_user = 0
#           }
#           name = "wordpress-cli-container-2"
#           image = "wordpress:cli"
#           command = ["wp", "--allow-root", "plugin", "install", "wp-stateless", "--activate", "--path=/var/www/html"]
#           volume_mount {
#             name = "wordpress-pv"
#             mount_path = "/var/www/html"
#           }
#         }
#         container {
#           security_context {
#             run_as_user = 0
#           }
#           name = "wordpress-container"
#           image = "wordpress:latest"
#           env {
#             name = "WORDPRESS_DB_HOST"
#             value = "mysql-service"
#           }
#           env {
#             name = "WORDPRESS_DB_NAME"
#             value_from {
#               secret_key_ref {
#                 name = "mysql-credentials-secret"
#                 key = "database"
#               }
#             }
#           }
#           env {
#             name = "WORDPRESS_DB_USER"
#             value_from {
#               secret_key_ref {
#                 name = "mysql-credentials-secret"
#                 key = "user"
#               }
#             }
#           }
#           env {
#             name = "WORDPRESS_DB_PASSWORD"
#             value_from {
#               secret_key_ref {
#                 name = "mysql-credentials-secret"
#                 key = "password"
#               }
#             }
#           }
#           env {
#             name = "WORDPRESS_CONFIG_EXTRA"
#             value = <<EOF
# define( 'WP_STATELESS_MEDIA_MODE', 'stateless' );
# define( 'WP_STATELESS_MEDIA_BUCKET', '${var.bucket_name}' );
# define( 'WP_STATELESS_MEDIA_CACHE_BUSTING', 'true' );
# define( 'WP_STATELESS_MEDIA_KEY_FILE_PATH', '/etc/ssl/private/service-account.json' );
# EOF
#           }
#           port {
#             container_port = 80
#           }
#           volume_mount {
#             name = "wordpress-pv"
#             mount_path = "/var/www/html"
#           }
#           volume_mount {
#             name = "wordpress-sa-key"
#             mount_path = "/etc/ssl/private/"
#           }
#         }
#         volume {
#           name = "wordpress-pv"
#           persistent_volume_claim {
#             claim_name = "wordpress-pvc"
#           }
#         }
#         volume {
#           name = "wordpress-sa-key"
#           secret {
#             secret_name = "wordpress-sa-secret"
#           }
#         }
#       }
#     }
#   }
#   depends_on = [kubernetes_secret.wordpress-sa-secret]
# }
