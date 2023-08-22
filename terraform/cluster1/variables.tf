variable "acme_email" {
  description = "The email used for Letsencrypt"
  type        = string
}

variable "domain" {
  description = "The public domain used for cert-manager and ingress"
  type        = string
}
