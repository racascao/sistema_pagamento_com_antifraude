# Managed Service for Apache Kafka replaces the local Redpanda in
# production. The application only speaks the Kafka protocol, so
# nothing changes in the services.

resource "google_managed_kafka_cluster" "events" {
  cluster_id = "payment-processor-events"
  location   = var.region

  capacity_config {
    vcpu_count   = var.kafka_vcpu
    memory_bytes = var.kafka_memory_bytes
  }

  gcp_config {
    access_config {
      network_configs {
        subnet = google_compute_subnetwork.main.id
      }
    }
  }

  rebalance_config {
    mode = "AUTO_REBALANCE_ON_SCALE_UP"
  }

  labels = {
    project     = "payment-processor"
    environment = var.environment
  }
}

resource "google_managed_kafka_topic" "payment_events" {
  topic_id           = "payments.events"
  cluster            = google_managed_kafka_cluster.events.cluster_id
  location           = var.region
  partition_count    = 3
  replication_factor = 3
}

resource "google_managed_kafka_topic" "review_events" {
  topic_id           = "reviews.events"
  cluster            = google_managed_kafka_cluster.events.cluster_id
  location           = var.region
  partition_count    = 3
  replication_factor = 3
}
