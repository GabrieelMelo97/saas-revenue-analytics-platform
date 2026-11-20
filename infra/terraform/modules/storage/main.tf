variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  description = "GCP Region for storage buckets"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, prod)"
}

variable "labels" {
  type        = map(string)
  description = "Standard FinOps labels applied to all resources"
}

resource "google_storage_bucket" "raw_landing" {
  name                        = "${var.project_id}-saas-rev-raw-${var.environment}"
  project                     = var.project_id
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.environment != "prod"
  labels                      = var.labels

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket" "quarantine" {
  name                        = "${var.project_id}-saas-rev-quarantine-${var.environment}"
  project                     = var.project_id
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.environment != "prod"
  labels                      = var.labels

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }
}

output "raw_bucket_name" {
  value       = google_storage_bucket.raw_landing.name
  description = "Name of the GCS raw landing bucket"
}

output "quarantine_bucket_name" {
  value       = google_storage_bucket.quarantine.name
  description = "Name of the GCS quarantine bucket"
}
