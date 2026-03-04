variable "project_id" {
  description = "The Google Cloud project ID to deploy into."
  type        = string
}

variable "region" {
  description = "The GCP region for the Cloud Function and supporting resources."
  type        = string
  default     = "us-central1"
}

variable "pubsub_topic" {
  description = "Name of the Pub/Sub topic to subscribe to."
  type        = string
  default     = "{{PUBSUB_TOPIC}}"
}

variable "function_name" {
  description = "Name for the Cloud Function resource."
  type        = string
  default     = "{{FUNCTION_NAME}}"
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
