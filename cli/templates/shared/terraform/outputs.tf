output "function_name" {
  description = "The name of the deployed Cloud Function."
  value       = module.cloud_function.function_name
}

output "function_uri" {
  description = "The HTTPS URI of the Cloud Function (Cloud Run service URL)."
  value       = module.cloud_function.function_uri
}

output "function_service_account" {
  description = "The service account email used by the Cloud Function."
  value       = module.cloud_function.service_account_email
}

output "source_bucket" {
  description = "The GCS bucket storing function source archives."
  value       = module.cloud_function.source_bucket
}

output "eventarc_trigger" {
  description = "The Eventarc trigger resource name. Empty string for HTTP-triggered functions."
  value       = module.cloud_function.eventarc_trigger
}

output "eventarc_custom_channel" {
  description = "The Eventarc channel for custom lifecycle events. Null when enable_custom_eventarc_channel is false."
  value       = module.cloud_function.custom_eventarc_channel
}
