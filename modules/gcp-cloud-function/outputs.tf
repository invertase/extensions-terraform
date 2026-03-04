output "function_name" {
  description = "Name of the deployed Cloud Function."
  value       = google_cloudfunctions2_function.fn.name
}

output "function_uri" {
  description = "HTTPS URI of the function's underlying Cloud Run service."
  value       = google_cloudfunctions2_function.fn.service_config[0].uri
}

output "service_account_email" {
  description = "Email of the service account created for the function."
  value       = google_service_account.fn.email
}

output "source_bucket" {
  description = "GCS bucket name holding function source archives."
  value       = google_storage_bucket.source.name
}

output "eventarc_trigger" {
  description = "Full resource name of the Eventarc trigger. Empty string for HTTP-triggered functions."
  value       = var.event_trigger != null ? google_cloudfunctions2_function.fn.event_trigger[0].trigger : ""
}

output "custom_eventarc_channel" {
  description = "Name of the custom Eventarc channel. Null when enable_custom_eventarc_channel is false."
  value       = var.enable_custom_eventarc_channel ? google_eventarc_channel.custom_events[0].name : null
}
