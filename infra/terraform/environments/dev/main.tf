locals {
  common_labels = {
    project    = "saas-revenue-analytics"
    env        = var.environment
    managed_by = "terraform"
    domain     = "revenue-analytics"
  }
}

module "storage" {
  source = "../../modules/storage"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.common_labels
}

module "bigquery" {
  source = "../../modules/bigquery"

  project_id  = var.project_id
  location    = var.bq_location
  environment = var.environment
  labels      = local.common_labels
}

module "iam" {
  source = "../../modules/iam"

  project_id             = var.project_id
  environment            = var.environment
  raw_bucket_name        = module.storage.raw_bucket_name
  quarantine_bucket_name = module.storage.quarantine_bucket_name
  dataset_ids            = module.bigquery.dataset_ids
}

module "compute" {
  source = "../../modules/compute"

  project_id          = var.project_id
  region              = var.region
  environment         = var.environment
  dbt_runner_sa_email = module.iam.dbt_runner_sa_email
  bi_reader_sa_email  = module.iam.bi_reader_sa_email
  raw_bucket_name     = module.storage.raw_bucket_name
  bq_dataset_raw      = module.bigquery.dataset_ids["raw"]
  bq_dataset_marts    = module.bigquery.dataset_ids["marts"]
  container_image     = var.container_image
  labels              = local.common_labels
}

module "finops" {
  source = "../../modules/finops"

  project_id          = var.project_id
  environment         = var.environment
  enable_budget_alert = var.enable_budget_alert
  billing_account_id  = var.billing_account_id
  monthly_budget_usd  = var.monthly_budget_usd
}
