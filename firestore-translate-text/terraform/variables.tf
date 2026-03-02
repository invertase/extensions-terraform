variable "project_id" {
  description = "The Google Cloud project ID to deploy into."
  type        = string
}

variable "region" {
  description = "The GCP region for the Cloud Function and supporting resources. Must match your Firestore database location."
  type        = string
  default     = "us-central1"
}

variable "collection_path" {
  description = "Firestore collection path to watch for writes (e.g. 'translations' or 'users/{uid}/messages'). Do not include a trailing document wildcard."
  type        = string
  default     = "translations"
}

variable "input_field_name" {
  description = "The name of the Firestore document field containing the string to translate."
  type        = string
  default     = "input"
}

variable "output_field_name" {
  description = "The name of the Firestore document field where translated strings will be written."
  type        = string
  default     = "translated"
}

variable "languages" {
  description = "Comma-separated list of ISO-639-1 language codes to translate into (e.g. 'en,es,de,fr')."
  type        = string
  default     = "en,es,de,fr"
}

variable "languages_field_name" {
  description = "Optional. Firestore document field that overrides the target languages per document. Leave empty to always use var.languages."
  type        = string
  default     = ""
}

variable "translation_provider" {
  description = "Translation provider to use. One of: 'translate' (Cloud Translation API), 'gemini-googleai', or 'gemini-vertexai'."
  type        = string
  default     = "translate"
  validation {
    condition     = contains(["translate", "gemini-googleai", "gemini-vertexai"], var.translation_provider)
    error_message = "translation_provider must be one of: translate, gemini-googleai, gemini-vertexai."
  }
}

variable "gemini_model" {
  description = "Gemini model to use when translation_provider is 'gemini-googleai' or 'gemini-vertexai'."
  type        = string
  default     = "gemini-2.5-flash"
}

variable "google_ai_api_key" {
  description = "Google AI API key. Required when translation_provider is 'gemini-googleai'. Stored in Secret Manager."
  type        = string
  default     = ""
  sensitive   = true
}

variable "function_name" {
  description = "Name for the Cloud Function resource."
  type        = string
  default     = "fstranslate"
}

variable "function_min_instances" {
  description = "Minimum number of Cloud Function instances (set > 0 to reduce cold starts)."
  type        = number
  default     = 0
}

variable "function_max_instances" {
  description = "Maximum number of Cloud Function instances."
  type        = number
  default     = 10
}

variable "function_memory_mb" {
  description = "Memory allocation for the Cloud Function in MB."
  type        = number
  default     = 256
}

variable "function_timeout_seconds" {
  description = "Timeout in seconds for the Cloud Function."
  type        = number
  default     = 60
}
