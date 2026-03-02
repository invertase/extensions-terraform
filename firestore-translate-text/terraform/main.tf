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

# ── Project number (needed for system service agent emails) ───────────────────

data "google_project" "project" {
  project_id = var.project_id
}

# ── Service account ───────────────────────────────────────────────────────────

resource "google_service_account" "translate_text" {
  project      = var.project_id
  account_id   = "${var.function_name}-sa"
  display_name = "Service Account for ${var.function_name} Cloud Function"

  depends_on = [google_project_service.apis]
}

# ── IAM bindings ──────────────────────────────────────────────────────────────

resource "google_project_iam_member" "datastore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.translate_text.email}"
}

resource "google_project_iam_member" "eventarc_receiver" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.translate_text.email}"
}

resource "google_project_iam_member" "run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.translate_text.email}"
}

resource "google_project_iam_member" "log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.translate_text.email}"
}

# Allow the Eventarc service agent to generate tokens for the function SA.
# Required for Firestore-triggered Gen 2 functions.
resource "google_project_iam_member" "eventarc_sa_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-eventarc.iam.gserviceaccount.com"

  depends_on = [google_project_service.apis]
}

# Vertex AI user role — only needed for the gemini-vertexai provider.
resource "google_project_iam_member" "vertex_ai_user" {
  count = var.translation_provider == "gemini-vertexai" ? 1 : 0

  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.translate_text.email}"
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
  member    = "serviceAccount:${google_service_account.translate_text.email}"
}

# ── Custom Eventarc channel (opt-in) ─────────────────────────────────────────

resource "google_eventarc_channel" "custom_events" {
  count = var.enable_custom_events ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = "${var.function_name}-events"

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "eventarc_publisher" {
  count = var.enable_custom_events ? 1 : 0

  project = var.project_id
  role    = "roles/eventarc.publisher"
  member  = "serviceAccount:${google_service_account.translate_text.email}"
}

# ── Source bucket + archive ───────────────────────────────────────────────────

resource "google_storage_bucket" "function_source" {
  project                     = var.project_id
  name                        = "${var.project_id}-${var.function_name}-source"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  depends_on = [google_project_service.apis]
}

data "archive_file" "function_source" {
  type        = "zip"
  output_path = "${path.module}/${var.function_name}-source.zip"
  source_dir  = "${path.module}/../function"
  excludes = [
    "lib",
    "node_modules",
    "__tests__",
    "jest.config.js",
    ".env",
  ]
}

# Object name includes the source MD5 so any code change triggers redeployment.
resource "google_storage_bucket_object" "function_source" {
  name   = "${var.function_name}-${data.archive_file.function_source.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.function_source.output_path
}

# ── Cloud Function Gen 2 ──────────────────────────────────────────────────────

resource "google_cloudfunctions2_function" "translate_text" {
  project     = var.project_id
  location    = var.region
  name        = var.function_name
  description = "Translates strings written to Firestore into multiple languages."

  build_config {
    runtime     = "nodejs24"
    entry_point = "translateText"

    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.function_source.name
      }
    }
  }

  service_config {
    service_account_email          = google_service_account.translate_text.email
    min_instance_count             = var.function_min_instances
    max_instance_count             = var.function_max_instances
    available_memory               = "${var.function_memory_mb}Mi"
    timeout_seconds                = var.function_timeout_seconds
    all_traffic_on_latest_revision = true

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
        EVENTARC_CHANNEL    = google_eventarc_channel.custom_events[0].name
        EXT_SELECTED_EVENTS = join(",", var.custom_event_types)
      } : {}
    )

    dynamic "secret_environment_variables" {
      for_each = var.translation_provider == "gemini-googleai" ? [1] : []
      content {
        key        = "GOOGLE_AI_API_KEY"
        project_id = var.project_id
        secret     = google_secret_manager_secret.google_ai_api_key[0].secret_id
        version    = "latest"
      }
    }
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.firestore.document.v1.written"
    service_account_email = google_service_account.translate_text.email
    retry_policy          = "RETRY_POLICY_DO_NOT_RETRY"

    event_filters {
      attribute = "database"
      value     = "(default)"
    }

    event_filters {
      attribute = "document"
      value     = local.firestore_document_filter
      operator  = "match-path-pattern"
    }
  }

  depends_on = [
    google_project_service.apis,
    google_storage_bucket_object.function_source,
    google_project_iam_member.datastore_user,
    google_project_iam_member.eventarc_receiver,
    google_project_iam_member.run_invoker,
    google_project_iam_member.eventarc_sa_token_creator,
  ]
}
