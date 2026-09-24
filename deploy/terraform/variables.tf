variable "project_id" {
  description = "GCP project that hosts every resource"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name used in labels"
  type        = string
  default     = "production"
}

variable "gcp_access_token" {
  description = "Mock token for offline plans. Leave empty for real applies"
  type        = string
  default     = ""
  sensitive   = true
}

variable "subnet_cidr" {
  description = "Primary CIDR for the cluster subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary range for GKE pods"
  type        = string
  default     = "10.4.0.0/14"
}

variable "services_cidr" {
  description = "Secondary range for GKE services"
  type        = string
  default     = "10.8.0.0/20"
}

variable "gke_core_machine_type" {
  description = "Machine type for the core services node pool"
  type        = string
  default     = "e2-standard-2"
}

variable "gke_fraud_machine_type" {
  description = "Machine type for the fraud inference node pool, ARM"
  type        = string
  default     = "t2a-standard-2"
}

variable "db_tier" {
  description = "Cloud SQL machine tier for the ledger database"
  type        = string
  default     = "db-custom-2-7680"
}

variable "db_password" {
  description = "Password for the ledger database user"
  type        = string
  default     = "change-me-in-production"
  sensitive   = true
}

variable "kafka_vcpu" {
  description = "vCPU capacity of the Managed Kafka cluster"
  type        = number
  default     = 3
}

variable "kafka_memory_bytes" {
  description = "Memory capacity of the Managed Kafka cluster in bytes"
  type        = number
  default     = 3221225472
}
