# -----------------------------------------------------------------------------
# Enable Required APIs
# -----------------------------------------------------------------------------

resource "google_project_service" "run" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# Secret Manager - Store Sensitive Configuration
# -----------------------------------------------------------------------------

resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.service_name}-db-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}

resource "google_secret_manager_secret" "encryption_key" {
  secret_id = "${var.service_name}-encryption-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "encryption_key" {
  secret      = google_secret_manager_secret.encryption_key.id
  secret_data = var.n8n_encryption_key
}

# -----------------------------------------------------------------------------
# Service Account for Cloud Run
# -----------------------------------------------------------------------------

resource "google_service_account" "n8n" {
  account_id   = "${var.service_name}-sa"
  display_name = "n8n Cloud Run Service Account"

  depends_on = [google_project_service.iam]
}

resource "google_secret_manager_secret_iam_member" "db_password_accessor" {
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.n8n.email}"
}

resource "google_secret_manager_secret_iam_member" "encryption_key_accessor" {
  secret_id = google_secret_manager_secret.encryption_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.n8n.email}"
}

# -----------------------------------------------------------------------------
# Cloud Run Service
# -----------------------------------------------------------------------------

resource "google_cloud_run_v2_service" "n8n" {
  name     = var.service_name
  location = var.gcp_region

  ingress = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.n8n.email

    scaling {
      min_instance_count = var.cloud_run_min_instances
      max_instance_count = var.cloud_run_max_instances
    }

    containers {
      image = "docker.io/n8nio/n8n:latest"

      ports {
        container_port = 5678
      }

      resources {
        limits = {
          cpu    = var.cloud_run_cpu
          memory = var.cloud_run_memory
        }
        startup_cpu_boost = true
        cpu_idle          = false # Allocate CPU even outside of requests (required for triggers)
      }

      # Database configuration (using external Postgres)
      env {
        name  = "DB_TYPE"
        value = "postgresdb"
      }

      env {
        name  = "DB_POSTGRESDB_HOST"
        value = var.db_host
      }

      env {
        name  = "DB_POSTGRESDB_PORT"
        value = var.db_port
      }

      env {
        name  = "DB_POSTGRESDB_DATABASE"
        value = var.db_name
      }

      env {
        name  = "DB_POSTGRESDB_USER"
        value = var.db_user
      }

      env {
        name = "DB_POSTGRESDB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }

      env {
         name  = "DB_POSTGRESDB_SSL"
         value = "true"
      }

      env {
         name  = "DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED"
         value = "false"
      }

      # n8n encryption key
      env {
        name = "N8N_ENCRYPTION_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.encryption_key.secret_id
            version = "latest"
          }
        }
      }

      # n8n configuration
      env {
        name  = "N8N_PORT"
        value = "5678"
      }

      env {
        name  = "N8N_PROTOCOL"
        value = "https"
      }

      env {
        name  = "N8N_PROXY_HOPS"
        value = "1"
      }

      env {
        name  = "GENERIC_TIMEZONE"
        value = var.timezone
      }

      env {
        name  = "N8N_RUNNERS_ENABLED"
        value = "true"
      }

      # Basic auth (optional)
      dynamic "env" {
        for_each = var.n8n_basic_auth_active ? [1] : []
        content {
          name  = "N8N_BASIC_AUTH_ACTIVE"
          value = "true"
        }
      }

      dynamic "env" {
        for_each = var.n8n_basic_auth_active ? [1] : []
        content {
          name  = "N8N_BASIC_AUTH_USER"
          value = var.n8n_basic_auth_user
        }
      }

      dynamic "env" {
        for_each = var.n8n_basic_auth_active ? [1] : []
        content {
          name  = "N8N_BASIC_AUTH_PASSWORD"
          value = var.n8n_basic_auth_password
        }
      }

      # Startup probe
      startup_probe {
        initial_delay_seconds = 15
        timeout_seconds       = 5
        period_seconds        = 5
        failure_threshold     = 24
        tcp_socket {
          port = 5678
        }
      }

      liveness_probe {
        initial_delay_seconds = 60
        http_get {
          path = "/healthz"
          port = 5678
        }
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [
    google_project_service.run,
    google_secret_manager_secret_iam_member.db_password_accessor,
    google_secret_manager_secret_iam_member.encryption_key_accessor
  ]
}

# Allow public access to the service
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  project  = google_cloud_run_v2_service.n8n.project
  location = google_cloud_run_v2_service.n8n.location
  name     = google_cloud_run_v2_service.n8n.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
