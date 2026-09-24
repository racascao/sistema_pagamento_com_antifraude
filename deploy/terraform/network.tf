# VPC native networking for GKE: one subnet with secondary ranges for
# pods and services, plus Cloud NAT so private nodes reach the
# internet for image pulls and external APIs.

resource "google_compute_network" "main" {
  name                    = "payment-processor"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name          = "payment-processor-${var.region}"
  network       = google_compute_network.main.id
  region        = var.region
  ip_cidr_range = var.subnet_cidr

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  private_ip_google_access = true
}

resource "google_compute_router" "main" {
  name    = "payment-processor-router"
  network = google_compute_network.main.id
  region  = var.region
}

resource "google_compute_router_nat" "main" {
  name                               = "payment-processor-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Private services access so Cloud SQL gets a private IP inside the
# VPC instead of a public endpoint.
resource "google_compute_global_address" "private_services" {
  name          = "payment-processor-private-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
}
