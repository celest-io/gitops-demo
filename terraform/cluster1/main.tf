locals {
  domain       = var.domain
  datacenter   = "cluster1"
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

resource "kubernetes_secret" "cluster-secret-vars" {
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
