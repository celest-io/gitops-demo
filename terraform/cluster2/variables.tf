variable "acme_email" {
  description = "The email used for Letsencrypt"
  type        = string
}

variable "domain" {
  description = "The public domain used for cert-manager and ingress"
  type        = string
}

variable "repository_name" {
  description = "The path of the git repository using the format <user/org>/<repository>. Example: celest-io/gitops-demo"
  type        = string
}
