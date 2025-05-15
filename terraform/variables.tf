# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "gcp_project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "database_url" {
  description = "PostgreSQL connection URL (e.g., from NeonDB or Supabase)"
  type        = string
  sensitive   = true
}

variable "n8n_encryption_key" {
  description = "Encryption key for n8n credentials storage. Generate with: openssl rand -hex 32"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Optional Variables
# -----------------------------------------------------------------------------

variable "gcp_region" {
  description = "Google Cloud region for deployment"
  type        = string
  default     = "europe-west1"
}

variable "service_name" {
  description = "Name for the Cloud Run service"
  type        = string
  default     = "n8n"
}

variable "cloud_run_cpu" {
  description = "CPU allocation for Cloud Run (e.g., '1', '2')"
  type        = string
  default     = "1"
}

variable "cloud_run_memory" {
  description = "Memory allocation for Cloud Run (e.g., '512Mi', '1Gi', '2Gi')"
  type        = string
  default     = "1Gi"
}

variable "cloud_run_max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 1
}

variable "cloud_run_min_instances" {
  description = "Minimum number of Cloud Run instances (0 = scale to zero)"
  type        = number
  default     = 0
}

variable "n8n_basic_auth_active" {
  description = "Enable basic authentication for n8n"
  type        = bool
  default     = false
}

variable "n8n_basic_auth_user" {
  description = "Basic auth username (required if n8n_basic_auth_active is true)"
  type        = string
  default     = ""
}

variable "n8n_basic_auth_password" {
  description = "Basic auth password (required if n8n_basic_auth_active is true)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "timezone" {
  description = "Timezone for n8n (e.g., 'Europe/Berlin', 'America/New_York')"
  type        = string
  default     = "UTC"
}
