terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes" }
    kubectl    = { source = "gavinbunney/kubectl" }
    google     = { source = "hashicorp/google" }
    helm       = { source = "hashicorp/helm" }
  }
}

resource "kubernetes_namespace" "network" {
  metadata {
    name = "network"
  }
}

resource "helm_release" "cert_manager" {
  name = "cert-manager"
  namespace = "network"
  repository = "https://charts.jetstack.io"
  chart = "cert-manager"
  version = "1.3.0"
  set {
    name = "installCRDs"
    value = true
  }
  set {
    name = "ingressShim.defaultIssuerName"
    value = "cluster-issuer"
  }
  set {
    name = "ingressShim.defaultIssuerKind"
    value = "ClusterIssuer"
  }
  set {
    name = "ingressShim.defaultIssuerGroup"
    value =  "cert-manager.io"
  }
  depends_on = [kubernetes_namespace.network]
}

resource "kubernetes_secret" "dns_admin_sa_credentials" {
  metadata {
    name = "dns-admin-sa-credentials"
    namespace = "network"
  }
  data = {
    "service-account.json" = "${file(var.dns_admin_sa_credentials_path)}" 
  }
  depends_on = [kubernetes_namespace.network]
}

resource "kubectl_manifest" "cluster_issuer" {
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: cluster-issuer
spec:
  acme:
    email: ${var.acme_email}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: issuer-account-key
    solvers:
      - dns01:
          cloudDNS:
            project: ${var.project_id}
            serviceAccountSecretRef:
              name: dns-admin-sa-credentials
              key: service-account.json
YAML
  depends_on = [kubernetes_secret.dns_admin_sa_credentials]
}

resource "helm_release" "ingress_nginx" {
  name = "ingress-nginx-controller"
  namespace = "network"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart = "ingress-nginx"
  set { 
    name = "controller.replicaCount"
    value = 3
  }
  set {
    name = "controller.minAvailable"
    value = 2
  }
  set {
    name  = "controller.metrics.enabled"
    value = true
  }
  depends_on = [kubernetes_namespace.network]
}

module "shell_execute" {
  source = "github.com/matti/terraform-shell-resource"
  command = "kubectl -n network get svc ingress-nginx-controller-controller -o json | jq .status.loadBalancer.ingress[0].ip | tr -d '\"'"
  depends_on = [helm_release.ingress_nginx]
}

resource "google_dns_record_set" "dns_record" {
  name = "${var.dns_entry}."
  managed_zone = var.dns_zone_name
  rrdatas = [module.shell_execute.stdout]
  type = "A"
  ttl = 360
}
