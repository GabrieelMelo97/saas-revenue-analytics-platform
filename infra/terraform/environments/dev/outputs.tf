output "raw_bucket_name" {
  value       = module.storage.raw_bucket_name
  description = "GCS raw landing bucket"
}

output "quarantine_bucket_name" {
  value       = module.storage.quarantine_bucket_name
  description = "GCS quarantine bucket"
}

output "bigquery_datasets" {
  value       = module.bigquery.dataset_ids
  description = "Provisioned BigQuery datasets by layer"
}

output "cloud_run_job_name" {
  value       = module.compute.cloud_run_job_name
  description = "Serverless dbt runner Cloud Run Job"
}

output "service_accounts" {
  value = {
    ingestion  = module.iam.ingestion_sa_email
    dbt_runner = module.iam.dbt_runner_sa_email
    bi_reader  = module.iam.bi_reader_sa_email
  }
  description = "Least-privilege Service Accounts provisioned by Terraform"
}
