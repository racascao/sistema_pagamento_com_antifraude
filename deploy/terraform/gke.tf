# GKE Standard cluster with two node pools. Core services and the
# fraud inference pool scale independently, which is the reason the
# fraud service exists as its own deployment in the first place.
# Managed Service for Prometheus is enabled at the cluster level.

resource "google_container_cluster" "main" {
  name     = "payment-processor"
  location = var.region

  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.main.id

  # Node pools are managed as separate resources below.
  remove_default_node_pool = true
  initial_node_count       = 1

  # NOTE: node_config on this resource only affects the transient
  # default pool at *initial* cluster creation (remove_default_node_pool
  # deletes it immediately after) — once the cluster exists, Terraform
  # cannot "update" a pool that's already gone, so don't add it here
  # post-hoc. If SSD_TOTAL_GB quota is tight on a from-scratch apply,
  # set it before the first apply instead:
  #   node_config { disk_type = "pd-standard", disk_size_gb = 30 }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  monitoring_config {
    managed_prometheus {
      enabled = true
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  deletion_protection = false

  resource_labels = {
    project     = "payment-processor"
    environment = var.environment
  }
}

resource "google_service_account" "gke_nodes" {
  account_id   = "payment-processor-nodes"
  display_name = "GKE nodes for payment processor"
}

resource "google_project_iam_member" "gke_nodes_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_artifacts" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Managed Kafka requires SASL_SSL/OAUTHBEARER (plain TCP, as used by
# the local Redpanda setup, is refused) — gateway/ledger/investigator
# authenticate as this GSA via Workload Identity to get that token.
resource "google_project_iam_member" "gke_nodes_kafka" {
  project = var.project_id
  role    = "roles/managedkafka.client"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Lets the "default" KSA in the payment-processor namespace impersonate
# this GSA (Workload Identity). The KSA side still needs the matching
# annotation — see deploy/README.md step 4.
resource "google_service_account_iam_member" "gke_nodes_workload_identity" {
  service_account_id = google_service_account.gke_nodes.name
  role                = "roles/iam.workloadIdentityUser"
  member              = "serviceAccount:${var.project_id}.svc.id.goog[payment-processor/default]"
}

resource "google_container_node_pool" "core" {
  name     = "core-services"
  cluster  = google_container_cluster.main.id
  location = var.region

  # This project's CPUS_ALL_REGIONS quota is only 12 vCPU — an
  # unrestricted regional node pool multiplies initial_node_count
  # across every zone in the region, which alone exhausted it. Pin
  # to one zone so both pools fit the quota.
  node_locations = ["${var.region}-a"]

  autoscaling {
    min_node_count = 2
    max_node_count = 4
  }
  initial_node_count = 2

  node_config {
    machine_type    = var.gke_core_machine_type
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = { workload = "core" }

    disk_type    = "pd-standard"
    disk_size_gb = 50

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

resource "google_container_node_pool" "fraud" {
  name     = "fraud-inference"
  cluster  = google_container_cluster.main.id
  location = var.region

  # t2a-standard-2 (ARM) isn't offered in every zone of the region
  # (e.g. missing from us-central1-c), and CPUS_ALL_REGIONS quota is
  # only 12 vCPU total for this project (shared with core-services) —
  # pin to a single zone that has t2a to keep both pools within it.
  node_locations = ["${var.region}-a"]

  autoscaling {
    min_node_count = 1
    max_node_count = 8
  }
  initial_node_count = 2

  node_config {
    machine_type    = var.gke_fraud_machine_type
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = { workload = "fraud-inference" }

    disk_type    = "pd-standard"
    disk_size_gb = 50

    taint {
      key    = "workload"
      value  = "fraud-inference"
      effect = "NO_SCHEDULE"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

# Home for the four service images.
resource "google_artifact_registry_repository" "images" {
  repository_id = "payment-processor"
  location      = var.region
  format        = "DOCKER"
  description   = "Service images for the payment processor"
}
