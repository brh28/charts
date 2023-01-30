variable "testflight_namespace" {}

locals {
  cluster_name     = "galoy-staging-cluster"
  cluster_location = "us-east1"
  gcp_project      = "galoy-staging"

  smoketest_namespace  = "galoy-staging-smoketest"
  testflight_namespace = var.testflight_namespace
}

resource "kubernetes_namespace" "testflight" {
  metadata {
    name = local.testflight_namespace
  }
}

data "kubernetes_secret" "bitcoind_rpcpassword" {
  metadata {
    name      = "bitcoind-rpcpassword"
    namespace = "galoy-staging-bitcoin"
  }
}

resource "kubernetes_secret" "bitcoind_rpcpassword" {
  metadata {
    name      = "bitcoind-rpcpassword"
    namespace = kubernetes_namespace.testflight.metadata[0].name
  }

  data = data.kubernetes_secret.bitcoind_rpcpassword.data
}

resource "kubernetes_secret" "smoketest" {
  metadata {
    name      = local.testflight_namespace
    namespace = local.smoketest_namespace
  }
  data = {
    fulcrum_api_endpoint = "fulcrum.${local.testflight_namespace}.svc.cluster.local"
  }
}

resource "helm_release" "fulcrum" {
  name       = "fulcrum"
  chart      = "${path.module}/chart"
  repository = "https://galoymoney.github.io/charts/"
  namespace  = kubernetes_namespace.testflight.metadata[0].name

  dependency_update = true

  values = [
    file("${path.module}/testflight-values.yml")
  ]

  depends_on = [
    kubernetes_secret.bitcoinrpc_password
  ]
}

data "google_container_cluster" "primary" {
  project  = local.gcp_project
  name     = local.cluster_name
  location = local.cluster_location
}

data "google_client_config" "default" {
  provider = google-beta
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.primary.private_cluster_config.0.private_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}

provider "kubernetes-alpha" {
  host                   = "https://${data.google_container_cluster.primary.private_cluster_config.0.private_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.primary.private_cluster_config.0.private_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
  }
}