locals {
  required_apis = [
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "translate.googleapis.com",
    "eventarc.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "firestore.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
  ]

  # Append {document=**} wildcard for the Eventarc path pattern filter.
  # This matches any document within the collection (and any subcollections).
  firestore_document_filter = "${var.collection_path}/{document=**}"
}

# ── APIs ──────────────────────────────────────────────────────────────────────

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ── Project number (needed by the module for Eventarc service agent IAM) ──────

data "google_project" "project" {
  project_id = var.project_id
}

# ── Extension-specific IAM: Firestore access ──────────────────────────────────

resource "google_project_iam_member" "datastore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${module.cloud_function.service_account_email}"

  depends_on = [google_project_service.apis]
}

# ── Extension-specific IAM: Vertex AI (gemini-vertexai only) ──────────────────

resource "google_project_iam_member" "vertex_ai_user" {
  count = var.translation_provider == "gemini-vertexai" ? 1 : 0

  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${module.cloud_function.service_account_email}"
}

# ── Secret Manager (Google AI API key, gemini-googleai only) ──────────────────

resource "google_secret_manager_secret" "google_ai_api_key" {
  count = var.translation_provider == "gemini-googleai" ? 1 : 0

  project   = var.project_id
  secret_id = "${var.function_name}-google-ai-api-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "google_ai_api_key" {
  count = var.translation_provider == "gemini-googleai" ? 1 : 0

  secret      = google_secret_manager_secret.google_ai_api_key[0].id
  secret_data = var.google_ai_api_key
}

resource "google_secret_manager_secret_iam_member" "translate_text_secret_access" {
  count = var.translation_provider == "gemini-googleai" ? 1 : 0

  project   = var.project_id
  secret_id = google_secret_manager_secret.google_ai_api_key[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.cloud_function.service_account_email}"
}

# ── Cloud Function (via shared module) ───────────────────────────────────────

module "cloud_function" {
  source = "../../modules/gcp-cloud-function"

  project_id     = var.project_id
  project_number = data.google_project.project.number
  region         = var.region

  function_name        = var.function_name
  function_description = "Translates strings written to Firestore into multiple languages."

  runtime     = "nodejs24"
  entry_point = "translateText"
  source_dir  = "${path.module}/../function"

  min_instance_count = var.function_min_instances
  max_instance_count = var.function_max_instances
  function_memory_mb = var.function_memory_mb
  timeout_seconds    = var.function_timeout_seconds

  enable_custom_eventarc_channel = var.enable_custom_events

  environment_variables = merge(
    {
      LANGUAGES            = var.languages
      COLLECTION_PATH      = var.collection_path
      INPUT_FIELD_NAME     = var.input_field_name
      OUTPUT_FIELD_NAME    = var.output_field_name
      LANGUAGES_FIELD_NAME = var.languages_field_name
      TRANSLATION_PROVIDER = var.translation_provider
      GEMINI_MODEL         = var.gemini_model
      LOCATION             = var.region
      PROJECT_ID           = var.project_id
    },
    var.enable_custom_events ? {
      EVENTARC_CHANNEL    = module.cloud_function.custom_eventarc_channel
      EXT_SELECTED_EVENTS = join(",", var.custom_event_types)
    } : {}
  )

  secret_environment_variables = var.translation_provider == "gemini-googleai" ? [
    {
      env_var   = "GOOGLE_AI_API_KEY"
      secret_id = google_secret_manager_secret.google_ai_api_key[0].secret_id
      version   = "latest"
    }
  ] : []

  event_trigger = {
    event_type     = "google.cloud.firestore.document.v1.written"
    trigger_region = var.region
    retry_policy   = "RETRY_POLICY_DO_NOT_RETRY"
    event_filters = [
      {
        attribute = "database"
        value     = "(default)"
        operator  = null
      },
      {
        attribute = "document"
        value     = local.firestore_document_filter
        operator  = "match-path-pattern"
      },
    ]
  }

  depends_on = [google_project_service.apis]
}
