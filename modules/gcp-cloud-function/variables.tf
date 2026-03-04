# ── Identity ──────────────────────────────────────────────────────────────────

variable "project_id" {
  description = "The Google Cloud project ID to deploy into."
  type        = string
}

variable "project_number" {
  description = "The Google Cloud project number. Required to construct the Eventarc service agent email."
  type        = string
}

variable "region" {
  description = "GCP region for the Cloud Function, GCS bucket, and Eventarc trigger."
  type        = string
}

# ── Naming ────────────────────────────────────────────────────────────────────

variable "function_name" {
  description = "Name of the Cloud Function resource. Also used as a prefix for the service account and GCS bucket."
  type        = string
}

variable "function_description" {
  description = "Human-readable description for the Cloud Function resource."
  type        = string
  default     = ""
}

# ── Build ─────────────────────────────────────────────────────────────────────

variable "runtime" {
  description = "Cloud Functions runtime identifier (e.g. 'nodejs24', 'python312')."
  type        = string
  default     = "nodejs24"
}

variable "entry_point" {
  description = "Name of the exported function in the source code that Cloud Functions will invoke."
  type        = string
}

variable "source_dir" {
  description = "Absolute path to the directory containing function source code. The directory is zipped and uploaded to GCS."
  type        = string
}

variable "source_excludes" {
  description = "List of file/directory names to exclude from the source archive."
  type        = list(string)
  default     = ["lib", "node_modules", "__tests__", "jest.config.js", ".env"]
}

# ── Scaling & resources ───────────────────────────────────────────────────────

variable "min_instance_count" {
  description = "Minimum number of Cloud Function instances (set > 0 to reduce cold starts)."
  type        = number
  default     = 0
}

variable "max_instance_count" {
  description = "Maximum number of Cloud Function instances."
  type        = number
  default     = 10
}

variable "function_memory_mb" {
  description = "Memory allocation for the Cloud Function in MB."
  type        = number
  default     = 256
}

variable "timeout_seconds" {
  description = "Maximum duration (in seconds) the function is allowed to run before being killed."
  type        = number
  default     = 60
}

# ── IAM ───────────────────────────────────────────────────────────────────────

variable "additional_sa_roles" {
  description = "Extra project-level IAM roles to grant the function's service account, beyond the always-granted core roles (logging.logWriter, run.invoker, eventarc.eventReceiver)."
  type        = list(string)
  default     = []
}

# ── Trigger type ──────────────────────────────────────────────────────────────

variable "enable_https_trigger" {
  description = "When true, deploys the function as an HTTP-triggered function instead of an event-triggered one. Mutually exclusive with event_trigger."
  type        = bool
  default     = false
}

# ── Custom Eventarc channel (opt-in) ──────────────────────────────────────────

variable "enable_custom_eventarc_channel" {
  description = "When true, creates a named Eventarc channel and grants the function SA the eventarc.publisher role."
  type        = bool
  default     = false
}

# ── Environment variables ─────────────────────────────────────────────────────

variable "environment_variables" {
  description = "Plain-text environment variables to inject into the function at runtime."
  type        = map(string)
  default     = {}
}

variable "secret_environment_variables" {
  description = <<-EOT
    Secrets to inject as environment variables from Secret Manager.
    The secret resources must already exist (managed outside this module).

    Example:
      [{
        env_var   = "GOOGLE_AI_API_KEY"
        secret_id = "my-function-google-ai-api-key"
        version   = "latest"
      }]
  EOT
  type = list(object({
    env_var   = string
    secret_id = string
    version   = string
  }))
  default = []
}

# ── Event trigger ─────────────────────────────────────────────────────────────

variable "event_trigger" {
  description = <<-EOT
    Configuration for the Eventarc trigger attached to the Cloud Function.
    Set to null (the default) when using enable_https_trigger = true.

    - event_type:     Eventarc event type string.
    - trigger_region: Region where the trigger listens (must match the event source region).
    - retry_policy:   One of RETRY_POLICY_UNSPECIFIED, RETRY_POLICY_DO_NOT_RETRY, RETRY_POLICY_RETRY.
    - event_filters:  List of attribute filter objects. Each has:
        - attribute: The event attribute name (e.g. "database", "document").
        - value:     The value to match.
        - operator:  Optional. Omit or set null for exact match; use "match-path-pattern" for glob-style paths.

    Example (Firestore document.written):
      {
        event_type     = "google.cloud.firestore.document.v1.written"
        trigger_region = "us-central1"
        retry_policy   = "RETRY_POLICY_DO_NOT_RETRY"
        event_filters  = [
          { attribute = "database", value = "(default)", operator = null },
          { attribute = "document", value = "translations/{document=**}", operator = "match-path-pattern" }
        ]
      }
  EOT
  type = object({
    event_type     = string
    trigger_region = string
    retry_policy   = string
    event_filters = list(object({
      attribute = string
      value     = string
      operator  = optional(string)
    }))
  })
  default = null
}
