output "function_name" {
  description = "The name of the deployed Cloud Function."
  value       = google_cloudfunctions2_function.translate_text.name
}

output "function_uri" {
  description = "The HTTPS URI of the Cloud Function (Cloud Run service URL). Access is via Eventarc trigger only — not publicly invocable."
  value       = google_cloudfunctions2_function.translate_text.service_config[0].uri
}

output "function_service_account" {
  description = "The service account email used by the Cloud Function."
  value       = google_service_account.translate_text.email
}

output "source_bucket" {
  description = "The GCS bucket storing function source archives."
  value       = google_storage_bucket.function_source.name
}

output "eventarc_trigger" {
  description = "The Eventarc trigger name created for the Firestore document.written event."
  value       = google_cloudfunctions2_function.translate_text.event_trigger[0].trigger
}

output "eventarc_custom_channel" {
  description = "The Eventarc channel for custom lifecycle events (onStart, onError, onSuccess, onCompletion). Only set when enable_custom_events is true."
  value       = var.enable_custom_events ? google_eventarc_channel.custom_events[0].name : null
}
