variable "testflight_namespace" {}

locals {
  cluster_name     = "galoy-staging-cluster"
  cluster_location = "us-east1"
  gcp_project      = "galoy-staging"

  smoketest_namespace  = "galoy-staging-smoketest"
  testflight_namespace = var.testflight_namespace

  session_keys = "session-keys"
}

resource "kubernetes_namespace" "testflight" {
  metadata {
    name = local.testflight_namespace
  }
}

resource "kubernetes_secret" "smoketest" {
  metadata {
    name      = local.testflight_namespace
    namespace = local.smoketest_namespace
  }
  data = {
    web_wallet_endpoint        = "web-wallet.${local.testflight_namespace}.svc.cluster.local"
    web_wallet_mobile_endpoint = "web-wallet-mobile.${local.testflight_namespace}.svc.cluster.local"
    web_wallet_port            = 80
  }
}

resource "kubernetes_secret" "web_wallet" {
  metadata {
    name      = "web-wallet"
    namespace = local.testflight_namespace
  }
  data = {
    "session-keys" : local.session_keys
  }
}

resource "helm_release" "web_wallet" {
  name       = "web-wallet"
  chart      = "${path.module}/chart"
  repository = "https://galoymoney.github.io/charts/"
  namespace  = kubernetes_namespace.testflight.metadata[0].name
}

resource "kubernetes_secret" "web_wallet_mobile" {
  metadata {
    name      = "web-wallet-mobile"
    namespace = local.testflight_namespace
  }
  data = {
    "session-keys" : local.session_keys
  }
}

resource "helm_release" "web_wallet_mobile" {
  name       = "web-wallet-mobile"
  chart      = "${path.module}/chart"
  repository = "https://galoymoney.github.io/charts/"
  namespace  = kubernetes_namespace.testflight.metadata[0].name

  values = [
    file("${path.module}/web-wallet-mobile-testflight-values.yml")
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
