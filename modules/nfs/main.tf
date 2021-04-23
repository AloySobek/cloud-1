terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes" }
    helm = { source = "hashicorp/helm" }
  }
}

resource "kubernetes_service" "nfs_service" {
  metadata {
    name = "nfs-service"
    namespace = "storage"
    labels = {
      "app" = "nfs-server"
    }
  }
  spec {
    selector = {
      "app" = "nfs-server"
    }
    port {
      port = 2049
      target_port = 2049
    }
  }
}

resource "kubernetes_persistent_volume_claim" "nfs_pvc" {
  metadata {
    name = "nfs-pvc"
    namespace = "storage"
    labels = {
      "app" = "nfs-server"
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "standard"
    resources {
      requests = {
        "storage" = "16Gi" 
      }
    }
  }
}

resource "kubernetes_deployment" "nfs_deployment" {
  metadata {
    name = "nfs-deployment"
    namespace = "storage"
    labels = {
      "app" = "nfs-server"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        "app" = "nfs-server" 
      }
    }
    template {
      metadata {
        name = "nfs-pod"
        labels = {
          "app" = "nfs-server"
        }
      }
      spec {
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key = "kubernetes.io/hostname"
                  operator = "In"
                  values = [var.hostname]
                }
              }
            }
          }
        }
        container {
          name = "nfs-container"
          image = "itsthenetwork/nfs-server-alpine"
          image_pull_policy = "IfNotPresent"
          port {
            container_port = 2049
          }
          security_context {
            allow_privilege_escalation = true
            privileged = true
            run_as_user = 0
          }
          env {
            name = "SHARED_DIRECTORY"
            value = "/shared"
          }
          env {
            name = "SYNC"
            value = "true"
          }
          volume_mount {
            name = "standard"
            mount_path = "/shared"
          }
        }
        volume {
          name = "standard"
          persistent_volume_claim {
            claim_name = "nfs-pvc"
          }
        }
      }
    }
  }
  depends_on = [kubernetes_persistent_volume_claim.nfs_pvc]
}

resource "helm_release" "nfs_subdir_external_provisioner" {
  name = "nfs-subdir-external-provisioner"
  namespace = "storage"
  repository = "https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner"
  chart = "nfs-subdir-external-provisioner"
  values = [
<<YAML
nfs:
  server: ${kubernetes_service.nfs_service.spec[0].cluster_ip}
  path: /
storageClass:
  name: nfs
YAML
  ]
  depends_on = [kubernetes_deployment.nfs_deployment]
}
