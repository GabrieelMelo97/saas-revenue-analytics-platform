variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  description = "GCP Region"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "dbt_runner_sa_email" {
  type        = string
  description = "Service Account email for the Cloud Run Job"
}

variable "bi_reader_sa_email" {
  type        = string
  description = "Least-privilege read-only Service Account email for the BI Dashboard Cloud Run Service"
}

variable "allow_unauthenticated_dashboard" {
  type        = bool
  default     = false
  description = "Allow public HTTPS access to the portfolio Streamlit dashboard (opt-in)"
}

variable "raw_bucket_name" {
  type        = string
  description = "GCS raw bucket name"
}

variable "bq_dataset_raw" {
  type        = string
  description = "BigQuery raw dataset ID"
}

variable "bq_dataset_marts" {
  type        = string
  description = "BigQuery marts dataset ID"
}

variable "container_image" {
  type        = string
  description = "Container image URI in Artifact Registry"
}

variable "labels" {
  type        = map(string)
  description = "Standard FinOps labels"
}

resource "google_artifact_registry_repository" "dbt_images" {
  project       = var.project_id
  location      = var.region
  repository_id = "saas-revenue-${var.environment}"
  description   = "Container images for SaaS Revenue dbt runner"
  format        = "DOCKER"
  labels        = var.labels
}

resource "google_cloud_run_v2_job" "dbt_pipeline" {
  project  = var.project_id
  name     = "saas-revenue-dbt-job-${var.environment}"
  location = var.region
  labels   = var.labels

  template {
    template {
      service_account = var.dbt_runner_sa_email
      max_retries     = 1
      timeout         = "600s"

      containers {
        image = var.container_image

        resources {
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }

        env {
          name  = "APP_ENV"
          value = var.environment
        }
        env {
          name  = "TARGET_BACKEND"
          value = "gcp"
        }
        env {
          name  = "GCP_PROJECT_ID"
          value = var.project_id
        }
        env {
          name  = "GCP_REGION"
          value = var.region
        }
        env {
          name  = "GCP_BQ_LOCATION"
          value = "US"
        }
        env {
          name  = "GCP_RAW_BUCKET"
          value = var.raw_bucket_name
        }
        env {
          name  = "GCP_BQ_DATASET_RAW"
          value = var.bq_dataset_raw
        }
        env {
          name  = "GCP_BQ_DATASET_MARTS"
          value = var.bq_dataset_marts
        }
      }
    }
  }
}

resource "google_cloud_scheduler_job" "daily_dbt_trigger" {
  project     = var.project_id
  name        = "saas-revenue-daily-dbt-${var.environment}"
  region      = var.region
  description = "Triggers daily serverless dbt build on Cloud Run Jobs (06:00 UTC)"
  schedule    = "0 6 * * *"
  time_zone   = "Etc/UTC"

  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.dbt_pipeline.name}:run"

    oauth_token {
      service_account_email = var.dbt_runner_sa_email
    }
  }
}

resource "google_cloud_run_v2_service" "dashboard" {
  project  = var.project_id
  name     = "saas-revenue-dashboard-${var.environment}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"
  labels   = var.labels

  template {
    service_account = var.bi_reader_sa_email

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image   = var.container_image
      command = ["streamlit"]
      args = [
        "run",
        "src/saas_revenue/dashboard.py",
        "--server.port=8080",
        "--server.address=0.0.0.0",
        "--server.headless=true",
      ]

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
      }

      env {
        name  = "APP_ENV"
        value = var.environment
      }
      env {
        name  = "TARGET_BACKEND"
        value = "gcp"
      }
      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "GCP_BQ_DATASET_MARTS"
        value = var.bq_dataset_marts
      }
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "dashboard_public" {
  count = var.allow_unauthenticated_dashboard ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.dashboard.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "artifact_registry_repo" {
  value = google_artifact_registry_repository.dbt_images.name
}

output "cloud_run_job_name" {
  value = google_cloud_run_v2_job.dbt_pipeline.name
}

output "dashboard_url" {
  value       = google_cloud_run_v2_service.dashboard.uri
  description = "HTTPS URL of the Serverless Streamlit BI Dashboard on Cloud Run"
}
