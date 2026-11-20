variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "raw_bucket_name" {
  type        = string
  description = "Raw GCS bucket name"
}

variable "quarantine_bucket_name" {
  type        = string
  description = "Quarantine GCS bucket name"
}

variable "dataset_ids" {
  type        = map(string)
  description = "BigQuery dataset IDs by layer"
}

# Least-Privilege Service Accounts (zero static keys; use Workload Identity / OIDC)
resource "google_service_account" "ingestion" {
  project      = var.project_id
  account_id   = "sa-saas-ingest-${var.environment}"
  display_name = "SaaS Revenue Ingestion Service Account (${var.environment})"
}

resource "google_service_account" "dbt_runner" {
  project      = var.project_id
  account_id   = "sa-saas-dbt-${var.environment}"
  display_name = "SaaS Revenue dbt Runner Service Account (${var.environment})"
}

resource "google_service_account" "bi_reader" {
  project      = var.project_id
  account_id   = "sa-saas-bi-${var.environment}"
  display_name = "SaaS Revenue BI Reader Service Account (${var.environment})"
}

# Ingestion SA: write to raw/quarantine GCS buckets and BigQuery raw dataset only
resource "google_storage_bucket_iam_member" "ingestion_raw_writer" {
  bucket = var.raw_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.ingestion.email}"
}

resource "google_storage_bucket_iam_member" "ingestion_quarantine_writer" {
  bucket = var.quarantine_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.ingestion.email}"
}

resource "google_bigquery_dataset_iam_member" "ingestion_bq_raw_editor" {
  project    = var.project_id
  dataset_id = var.dataset_ids["raw"]
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.ingestion.email}"
}

# dbt Runner SA: run BigQuery jobs, load raw from GCS, write staging/intermediate/snapshots/marts
resource "google_storage_bucket_iam_member" "dbt_raw_bucket_admin" {
  bucket = var.raw_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.dbt_runner.email}"
}

resource "google_project_iam_member" "dbt_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.dbt_runner.email}"
}

resource "google_bigquery_dataset_iam_member" "dbt_transform_editors" {
  for_each   = toset(["raw", "staging", "intermediate", "snapshots", "marts"])
  project    = var.project_id
  dataset_id = var.dataset_ids[each.key]
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.dbt_runner.email}"
}

# BI Reader SA: read-only access strictly to governed marts dataset
resource "google_project_iam_member" "bi_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.bi_reader.email}"
}

resource "google_bigquery_dataset_iam_member" "bi_marts_viewer" {
  project    = var.project_id
  dataset_id = var.dataset_ids["marts"]
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.bi_reader.email}"
}

output "ingestion_sa_email" {
  value = google_service_account.ingestion.email
}

output "dbt_runner_sa_email" {
  value = google_service_account.dbt_runner.email
}

output "bi_reader_sa_email" {
  value = google_service_account.bi_reader.email
}
