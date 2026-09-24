terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Production uses a remote backend. Kept local here so the module
  # can be validated and planned without cloud credentials.
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "payment-processor"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region

  # A mock access token lets terraform plan run without credentials.
  # For real applies leave gcp_access_token empty and authenticate
  # with: gcloud auth application-default login
  access_token = var.gcp_access_token != "" ? var.gcp_access_token : null
}
