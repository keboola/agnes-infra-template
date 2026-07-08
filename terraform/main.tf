terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # REPLACE: set bucket and prefix for your customer
  backend "gcs" {
    bucket = "REPLACE-WITH-YOUR-TFSTATE-BUCKET"
    prefix = "REPLACE-WITH-YOUR-CUSTOMER-NAME"
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.region
  zone    = var.zone
}

module "agnes" {
  source = "github.com/keboola/agnes-the-ai-analyst//infra/modules/customer-instance?ref=infra-v1.15.0"

  gcp_project_id    = var.gcp_project_id
  region            = var.region
  zone              = var.zone
  customer_name     = var.customer_name
  seed_admin_email  = var.seed_admin_email
  data_source       = var.data_source
  keboola_stack_url = var.keboola_stack_url
  prod_instance     = var.prod_instance
  dev_instances     = var.dev_instances

  # Watchdog + DB-backup alerting (module >= infra-v1.14.0). Empty = the
  # watchdog still runs, alerts stay in journald + /var/log/agnes-watchdog.log
  # on the VM. Set to a Slack / Google Chat incoming-webhook URL to get paged.
  alert_webhook_url = var.alert_webhook_url
}

output "prod_ip" {
  description = "External IP of prod VM. UI at http://<ip>:8000"
  value       = module.agnes.prod_ip
}

output "instance_ips" {
  description = "Map of all instance names to their external IPs"
  value       = module.agnes.instance_ips
}

output "jwt_secret_name" {
  description = "Full resource name of the JWT secret in Secret Manager"
  value       = module.agnes.jwt_secret_name
}
