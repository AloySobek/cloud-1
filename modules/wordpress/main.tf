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

resource "kubernetes_secret" "wordpress-sa-secret" {
  metadata {
    name = "wordpress-sa-secret"
  }
  data = {
    "service-account.json" = "${file(var.bucket_sa_credentials_path)}"
  }
}


resource "kubernetes_config_map" "wordpress_init_container_script" {
  metadata {
    name = "wordpress-init-container-script"
  }
  data = {
    "configuration" = <<EOF
#!/bin/bash

CONF_FILE=wp-config.php

#if test -f "$CONF_FILE"; then
#    echo "$CONF_FILE exists exiting"
#    exit 0
#fi

# Use wait-for-it to ensure DB is running
curl https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh > wfi.sh
chmod +x ./wfi.sh
./wfi.sh -p 3306 -h $WORDPRESS_DB_HOST -t 180
rm -f ./wfi.sh

# Init /var/www/html folder with Wordpress core
wp core download --force

# Pull default config for docker
curl https://raw.githubusercontent.com/docker-library/wordpress/master/latest/php8.0/apache/wp-config-docker.php > wp-config-docker.php

# Set default Salt's
# Copied from https://github.com/docker-library/wordpress/blob/master/latest/php8.0/apache/docker-entrypoint.sh#L80
awk '
/put your unique phrase here/ {
	cmd = "head -c1m /dev/urandom | sha1sum | cut -d\\  -f1"
	cmd | getline str
	close(cmd)
	gsub("put your unique phrase here", str)
}
{ print }
' "wp-config-docker.php" > $CONF_FILE

# Install and configure site
wp core install --path="/var/www/html" --url="$SITE_URL" --title="$SITE_TITLE" --admin_user="$SITE_ADMIN_USER" --admin_password="$SITE_ADMIN_PASS" --admin_email="$SITE_ADMIN_EMAIL" --skip-email

# Instull plugins
wp plugin install wp-stateless --activate
wp plugin install really-simple-ssl --activate
EOF
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

resource "kubernetes_ingress" "wordpress-ingress" {
  metadata {
    name = "wordpress-ingress"
    annotations = {
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
            service_name = "wordpress-service"
            service_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "wordpress-service" {
  metadata {
    name = "wordpress-service"
    labels = {
      app = "wordpress"
    }
  }
  spec {
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
        security_context {
          fs_group = 2000
        }
        init_container {
          security_context {
            run_as_user = 33
          }
          name = "wordpress-cli-container-0"
          image = "wordpress:cli"
          command = ["/entrypoint/entrypoint.sh"]
          env {
            name = "WORDPRESS_DB_HOST"
            value = "10.16.5.11"
          }
          env {
            name = "WORDPRESS_DB_NAME"
            value = "wordpress"
          }
          env {
            name = "WORDPRESS_DB_USER"
            value = "wordpress"
          }
          env {
            name = "WORDPRESS_DB_PASSWORD"
            value = "wordpress"
          }
          env {
            name = "SITE_URL"
            value = "https://cloud-1.starquark.com"
          }
          env {
            name = "SITE_TITLE"
            value = "cloud-1"
          }
          env {
            name = "SITE_ADMIN_USER"
            value = "root"
          }
          env {
            name = "SITE_ADMIN_USER"
            value = "gpr1CL1ty3qCln5"
          }
          env {
            name = "SITE_ADMIN_EMAIL"
            value = "empty@email.com"
          }
          volume_mount {
            name = "wordpress-pv"
            mount_path = "/var/www/html"
          }
          volume_mount {
            name = "wordpress-init-container-script"
            mount_path = "/entrypoint"
          }
        }
        container {
          security_context {
            run_as_user = 0
          }
          name = "wordpress-container"
          image = "wordpress:php8.0-apache"
          env {
            name = "WORDPRESS_DB_HOST"
            value = "10.16.5.11"
          }
          env {
            name = "WORDPRESS_DB_NAME"
            value = "wordpress"
          }
          env {
            name = "WORDPRESS_DB_USER"
            value = "wordpress"
          }
          env {
            name = "WORDPRESS_DB_PASSWORD"
            value = "wordpress"
          }
          env {
            name = "WP_DEBUG"
            value = true
          }
          env {
            name = "WORDPRESS_CONFIG_EXTRA"
            value = <<EOF
define( 'WP_STATELESS_MEDIA_MODE', 'stateless' );
define( 'WP_STATELESS_MEDIA_BUCKET', '${var.bucket_name}' );
define( 'WP_STATELESS_MEDIA_CACHE_BUSTING', 'true' );
define( 'WP_STATELESS_MEDIA_KEY_FILE_PATH', '/etc/ssl/private/service-account.json' );
if (strpos($_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false)
   $_SERVER['HTTPS']='on';
define('WP_SITEURL', 'https://' . $_SERVER['HTTP_HOST'] . '/');
define('WP_HOME', 'https://' . $_SERVER['HTTP_HOST'] . '/');
EOF
          }
          port {
            container_port = 80
          }
          volume_mount {
            name = "wordpress-pv"
            mount_path = "/var/www/html"
          }
          volume_mount {
            name = "wordpress-sa-key"
            mount_path = "/etc/ssl/private/"
          }
        }
        volume {
          name = "wordpress-pv"
          persistent_volume_claim {
            claim_name = "wordpress-pvc"
          }
        }
        volume {
          name = "wordpress-sa-key"
          secret {
            secret_name = "wordpress-sa-secret"
          }
        }
        volume {
          name = "wordpress-init-container-script"
          config_map {
            default_mode = "0777"
            name = kubernetes_config_map.wordpress_init_container_script.metadata[0].name
            items {
              key = "configuration"
              path = "entrypoint.sh"
            }
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_persistent_volume_claim.wordpress-pvc,
    kubernetes_secret.wordpress-sa-secret,
    kubernetes_config_map.wordpress_init_container_script
  ]
}
