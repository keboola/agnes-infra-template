variable "gcp_project_id" {
  description = "GCP project ID (must have billing enabled)"
  type        = string
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "zone" {
  type    = string
  default = "europe-west1-b"
}

variable "customer_name" {
  description = "Short identifier (e.g. 'acme', 'grpn'). Used as prefix in resource names."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.customer_name))
    error_message = "customer_name must be lowercase, start with a letter, 2-21 chars."
  }
}

variable "seed_admin_email" {
  description = "Email of the first admin user (will be created on first login bootstrap)"
  type        = string
}

variable "data_source" {
  description = "Data source type: keboola | bigquery | csv"
  type        = string
  default     = "keboola"
}

variable "keboola_stack_url" {
  description = "Keboola Stack URL (only if data_source = keboola)"
  type        = string
  default     = ""
}

variable "prod_instance" {
  description = "Prod VM configuration"
  type = object({
    name         = string
    machine_type = optional(string, "e2-small")
    disk_size_gb = optional(number, 30)
    data_disk_gb = optional(number, 50)
    image_tag    = optional(string, "stable")
    upgrade_mode = optional(string, "auto")
    tls_mode     = optional(string, "none")
    domain       = optional(string, "")
    # Container memory caps (AGNES_APP_MEM_LIMIT / AGNES_SCHEDULER_MEM_LIMIT in
    # /opt/agnes/.env). Defaults match the compose defaults. Raise on a larger
    # VM together with the app's per-connection DuckDB budgets, or lower on a
    # tiny VM so the caps fit under host RAM. Requires module >= infra-v1.11.0.
    app_mem_limit       = optional(string, "4g")
    scheduler_mem_limit = optional(string, "2g")
    # Per-VM branding. The module (customer-instance) carries these fields; the
    # template's object type must list them too, otherwise terraform SILENTLY
    # DROPS them from tfvars before they reach the module and the instance
    # renders unbranded. All optional with empty/null defaults => no branding,
    # byte-identical to before. Requires a module ref that includes branding.
    theme       = optional(string, "")
    logo_svg    = optional(string, "")
    brand       = optional(string, "")
    brand_short = optional(string, "")
    subtitle    = optional(string, "")
    copyright   = optional(string, "")
    theme_colors = optional(object({
      primary        = optional(string)
      primary_dark   = optional(string)
      primary_light  = optional(string)
      background     = optional(string)
      surface        = optional(string)
      border         = optional(string)
      text_primary   = optional(string)
      text_secondary = optional(string)
      success        = optional(string)
      warning        = optional(string)
      error          = optional(string)
      font_primary   = optional(string)
      font_url       = optional(string)
      radius         = optional(string)
    }), {})
    custom_scripts = optional(list(object({
      name      = string
      enabled   = bool
      placement = string
      html      = string
    })), [])
  })
  default = {
    name      = "agnes-prod"
    image_tag = "stable"
  }
}

variable "dev_instances" {
  description = "List of dev VMs. Empty list = no dev VMs. Each entry can pin its own image_tag (e.g. :dev for floating, :dev-feature-xyz for a specific branch)."
  type = list(object({
    name         = string
    machine_type = optional(string, "e2-small")
    image_tag    = optional(string, "dev")
    # See prod_instance; same defaults. Requires module >= infra-v1.11.0.
    app_mem_limit       = optional(string, "4g")
    scheduler_mem_limit = optional(string, "2g")
    # Per-VM branding — mirror of prod_instance (see the note there).
    theme       = optional(string, "")
    logo_svg    = optional(string, "")
    brand       = optional(string, "")
    brand_short = optional(string, "")
    subtitle    = optional(string, "")
    copyright   = optional(string, "")
    theme_colors = optional(object({
      primary        = optional(string)
      primary_dark   = optional(string)
      primary_light  = optional(string)
      background     = optional(string)
      surface        = optional(string)
      border         = optional(string)
      text_primary   = optional(string)
      text_secondary = optional(string)
      success        = optional(string)
      warning        = optional(string)
      error          = optional(string)
      font_primary   = optional(string)
      font_url       = optional(string)
      radius         = optional(string)
    }), {})
    custom_scripts = optional(list(object({
      name      = string
      enabled   = bool
      placement = string
      html      = string
    })), [])
  }))
  default = []
}

variable "alert_webhook_url" {
  description = "Webhook for the host-side watchdog + DB-backup-verify alerts (Slack / Google Chat compatible {\"text\": ...} POST). Empty (default) = log-only on the VM. Requires module >= infra-v1.14.0. Keep the URL out of the repo — supply via terraform.tfvars or a CI secret."
  type        = string
  default     = ""
  sensitive   = true
}
