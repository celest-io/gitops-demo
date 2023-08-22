locals {
  domain       = var.domain
  datacenter   = "cluster2"
  environment  = "lab"
  cluster_name = "${local.environment}-${local.datacenter}"

  k8s_config = pathexpand("~/.kube/gitopsdemo-${local.cluster_name}-config.yaml")
}

provider "kubernetes" {
  config_path = local.k8s_config
}

data "cloudflare_zone" "main" {
  name = local.domain
}

data "cloudflare_api_token_permission_groups" "all" {}

# Token allowed to edit DNS entries and TLS certs for specific zone.
resource "cloudflare_api_token" "external_dns" {
  name = "${local.domain} External-DNS - ${local.cluster_name}"

  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all.zone["DNS Write"],
    ]
    resources = {
      "com.cloudflare.api.account.zone.${data.cloudflare_zone.main.id}" = "*"
    }
  }
}

provider "github" {}

resource "tls_private_key" "flux" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

data "github_repository" "flux" {
  full_name = var.repository_name
}

resource "github_repository_deploy_key" "this" {
  title      = "${local.cluster_name}-flux"
  repository = data.github_repository.flux.name
  key        = tls_private_key.flux.public_key_openssh
  read_only  = "false"
}

provider "flux" {
  kubernetes = {
    config_path = local.k8s_config
  }

  git = {
    url = "ssh://git@github.com/${data.github_repository.flux.full_name}.git"
    ssh = {
      username    = "git"
      private_key = tls_private_key.flux.private_key_pem
    }
  }
}

resource "flux_bootstrap_git" "this" {
  depends_on = [github_repository_deploy_key.this]

  path = "clusters/${local.environment}/${local.datacenter}"
}

resource "kubernetes_secret" "cluster-secret-vars" {
  depends_on = [flux_bootstrap_git.this]
  metadata {
    name      = "cluster-secret-vars"
    namespace = "flux-system"
  }

  data = {
    ENVIRONMENT   = local.environment
    DOMAIN        = local.domain
    DATACENTER    = local.datacenter
    CLUSTER_NAME  = local.cluster_name
    INGRESS_CLASS = "traefik-public"
    CF_API_TOKEN  = cloudflare_api_token.external_dns.value
    ACME_EMAIL    = var.acme_email
  }

  type = "Opaque"
}
