# Cloud SQL for PostgreSQL 16 with regional availability. pgvector is
# supported natively, so the fraud pattern store lives in the same
# instance exactly like the local environment. The instance has no
# public IP, access goes through the VPC peering.

resource "google_sql_database_instance" "ledger" {
  name             = "payment-processor-ledger"
  database_version = "POSTGRES_16"
  region           = var.region

  settings {
    tier              = var.db_tier
    # New projects default to ENTERPRISE_PLUS, which rejects the
    # db-custom-* tier family used here; pin ENTERPRISE explicitly.
    edition           = "ENTERPRISE"
    availability_type = "REGIONAL"
    disk_type         = "PD_SSD"
    disk_size         = 50
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.main.id
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
    }

    insights_config {
      query_insights_enabled = true
    }

    user_labels = {
      project     = "payment-processor"
      environment = var.environment
    }
  }

  deletion_protection = false

  depends_on = [google_service_networking_connection.private_services]
}

resource "google_sql_database" "payments" {
  name     = "payments"
  instance = google_sql_database_instance.ledger.name
}

resource "google_sql_user" "app" {
  name     = "postgres"
  instance = google_sql_database_instance.ledger.name
  password = var.db_password
}
