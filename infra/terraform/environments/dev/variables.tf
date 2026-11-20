variable "project_id" {
  type        = string
  description = "Target GCP Project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "Primary GCP region"
}

variable "bq_location" {
  type        = string
  default     = "US"
  description = "BigQuery multi-region or region"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment"
}

variable "container_image" {
  type        = string
  default     = "us-central1-docker.pkg.dev/your-gcp-project-id/saas-revenue-dev/dbt-runner:latest"
  description = "Docker image URI for the Cloud Run dbt Job"
}

variable "enable_budget_alert" {
  type        = bool
  default     = false
  description = "Whether to provision a GCP Billing Budget alert"
}

variable "billing_account_id" {
  type        = string
  default     = ""
  description = "GCP Billing Account ID (only needed if enable_budget_alert = true)"
}

variable "monthly_budget_usd" {
  type        = number
  default     = 10
  description = "Monthly FinOps budget threshold in USD"
}
