variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "location" {
  type        = string
  description = "BigQuery dataset location (e.g., US or southamerica-east1)"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, prod)"
}

variable "labels" {
  type        = map(string)
  description = "Standard FinOps labels"
}

locals {
  datasets = {
    raw          = "Validated raw B2B SaaS tables loaded via Write-Audit-Publish"
    staging      = "dbt staging layer (1:1 standardized views)"
    intermediate = "dbt intermediate layer (MRR spine and movement classification)"
    snapshots    = "dbt SCD Type 2 snapshots preserving plan and pricing history"
    marts        = "Governed public marts with enforced data contracts for BI & Finance"
  }
}

resource "google_bigquery_dataset" "layers" {
  for_each = local.datasets

  dataset_id                 = "${each.key}_${var.environment}"
  project                    = var.project_id
  location                   = var.location
  description                = each.value
  delete_contents_on_destroy = var.environment != "prod"
  labels                     = merge(var.labels, { layer = each.key })

  # FinOps guardrail in dev: expire temporary tables in staging/intermediate after 30 days
  default_table_expiration_ms = (
    var.environment == "dev" && contains(["staging", "intermediate"], each.key)
    ? 2592000000
    : null
  )
}

output "dataset_ids" {
  value       = { for k, v in google_bigquery_dataset.layers : k => v.dataset_id }
  description = "Map of Medallion/dbt layer names to BigQuery dataset IDs"
}
