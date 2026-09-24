output "gke_connect_command" {
  description = "Configure kubectl against the cluster"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.main.name} --region ${var.region} --project ${var.project_id}"
}

output "artifact_registry" {
  description = "Docker repository for service images"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
}

output "ledger_db_private_ip" {
  description = "Private IP for the DATABASE_URL of ledger and investigator"
  value       = google_sql_database_instance.ledger.private_ip_address
}

output "kafka_bootstrap" {
  description = "Bootstrap endpoint for KAFKA_BROKER"
  value       = "bootstrap.${google_managed_kafka_cluster.events.cluster_id}.${var.region}.managedkafka.${var.project_id}.cloud.goog:9092"
}
