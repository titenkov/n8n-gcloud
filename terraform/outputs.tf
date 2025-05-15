output "service_url" {
  description = "URL of the deployed n8n Cloud Run service"
  value       = google_cloud_run_v2_service.n8n.uri
}

output "service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_v2_service.n8n.name
}

output "service_account_email" {
  description = "Email of the service account used by Cloud Run"
  value       = google_service_account.n8n.email
}
