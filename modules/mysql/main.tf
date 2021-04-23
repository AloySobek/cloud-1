terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes" }
    helm       = { source = "hashicorp/helm" }
  }
}

resource "kubernetes_namespace" "storage" {
  metadata {
    name = "storage"
  }
}

resource "kubernetes_secret" "mysql_passwords" {
  metadata {
    name = "mysql-passwords"
    namespace = "storage"
  }
  data = {
    "mysql-root-password" = "${var.mysql_root_password}"
    "mysql-replication-password" = "${var.mysql_replication_password}"
    "mysql-password" = "${var.mysql_password}"
  }
  depends_on = [kubernetes_namespace.storage]
}

resource "kubernetes_config_map" "mysql_primary_configuration" {
  metadata {
    name = "mysql-primary-configuration"
    namespace = "storage"
  }
  data = {
    "configuration" = <<EOF
[mysqld]
default_authentication_plugin=mysql_native_password
skip-name-resolve
explicit_defaults_for_timestamp
basedir=/opt/bitnami/mysql
plugin_dir=/opt/bitnami/mysql/plugin
port=3306
socket=/opt/bitnami/mysql/tmp/mysql.sock
datadir=/bitnami/mysql/data
tmpdir=/opt/bitnami/mysql/tmp
max_allowed_packet=16M
bind-address=0.0.0.0
pid-file=/opt/bitnami/mysql/tmp/mysqld.pid
log-error=/opt/bitnami/mysql/logs/mysqld.log
character-set-server=UTF8
collation-server=utf8_general_ci
[client]
port=3306
socket=/opt/bitnami/mysql/tmp/mysql.sock
default-character-set=UTF8
plugin_dir=/opt/bitnami/mysql/plugin
[manager]
port=3306
socket=/opt/bitnami/mysql/tmp/mysql.sock
pid-file=/opt/bitnami/mysql/tmp/mysqld.pid
EOF
  }
  depends_on = [kubernetes_namespace.storage]
}

resource "kubernetes_config_map" "mysql_secondary_configuration" {
  metadata {
    name = "mysql-secondary-configuration"
    namespace = "storage"
  }
  data = {
    "configuration" = <<EOF
[mysqld]
default_authentication_plugin=mysql_native_password
skip-name-resolve
explicit_defaults_for_timestamp
basedir=/opt/bitnami/mysql
port=3306
socket=/opt/bitnami/mysql/tmp/mysql.sock
datadir=/bitnami/mysql/data
tmpdir=/opt/bitnami/mysql/tmp
max_allowed_packet=16M
bind-address=0.0.0.0
pid-file=/opt/bitnami/mysql/tmp/mysqld.pid
log-error=/opt/bitnami/mysql/logs/mysqld.log
character-set-server=UTF8
collation-server=utf8_general_ci
[client]
port=3306
socket=/opt/bitnami/mysql/tmp/mysql.sock
default-character-set=UTF8
[manager]
port=3306
socket=/opt/bitnami/mysql/tmp/mysql.sock
pid-file=/opt/bitnami/mysql/tmp/mysqld.pid
EOF
  }
  depends_on = [kubernetes_namespace.storage]
}

resource "helm_release" "mysql" {
  name = "mysql"
  namespace = "storage"
  repository = "https://charts.bitnami.com/bitnami"
  chart = "mysql"
  values = [
<<YAML
commonLabels:
  app: wordpress
  tier: backend
  service: mysql
architecture: replication
auth:
  database: wordpress
  username: wordpress
  replicationUser: replicator
  existingSecret: mysql-passwords
primary:
  existingConfigMap: mysql-primary-configuration
  resources:
    limits:
      cpu: 1000m 
      memory: 4096Mi
  persistence:
    storageClass: premium-rwo 
    size: 16Gi
secondary:
  replicaCount: 1 
  existingConfigMap: mysql-secondary-configuration
  resources:
    limits:
      cpu: 500m 
      memory: 1024Mi
  persistence:
    storageClass: standard
    size: 16Gi
YAML
  ]
  depends_on = [
    kubernetes_secret.mysql_passwords,
    kubernetes_config_map.mysql_primary_configuration,
    kubernetes_config_map.mysql_secondary_configuration
  ]
}
