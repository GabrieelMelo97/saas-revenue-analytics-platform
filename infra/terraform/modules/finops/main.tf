variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "enable_budget_alert" {
  type        = bool
  default     = false
  description = "Enable GCP Billing Budget alert (requires billing_account_id)"
}

variable "billing_account_id" {
  type        = string
  default     = ""
  description = "GCP Billing Account ID"
}

variable "monthly_budget_usd" {
  type        = number
  default     = 10
  description = "Monthly budget cap in USD for FinOps alerts"
}

resource "google_billing_budget" "monthly_guardrail" {
  count = var.enable_budget_alert ? 1 : 0

  billing_account = var.billing_account_id
  display_name    = "saas-revenue-finops-budget-${var.environment}"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.monthly_budget_usd)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.8
  }
  threshold_rules {
    threshold_percent = 1.0
  }
}
