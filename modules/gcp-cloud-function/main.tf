# ── Service account ───────────────────────────────────────────────────────────

resource "google_service_account" "fn" {
  project      = var.project_id
  account_id   = "${var.function_name}-sa"
  display_name = "Service Account for ${var.function_name} Cloud Function"
}

# ── Core IAM bindings (always applied) ───────────────────────────────────────

locals {
  core_roles = toset([
    "roles/logging.logWriter",
    "roles/run.invoker",
    "roles/eventarc.eventReceiver",
  ])

  # Used by the dynamic event_trigger block — Terraform dynamic requires a collection.
  event_trigger_list = var.event_trigger != null ? [var.event_trigger] : []
}

resource "google_project_iam_member" "core" {
  for_each = local.core_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.fn.email}"
}

# Allow the Eventarc service agent to mint tokens for the function SA.
# Required for event-triggered Gen 2 functions.
resource "google_project_iam_member" "eventarc_sa_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:service-${var.project_number}@gcp-sa-eventarc.iam.gserviceaccount.com"
}

# ── Additional caller-specified roles ─────────────────────────────────────────

resource "google_project_iam_member" "additional" {
  for_each = toset(var.additional_sa_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.fn.email}"
}

# ── Custom Eventarc channel (opt-in) ──────────────────────────────────────────

resource "google_eventarc_channel" "custom_events" {
  count = var.enable_custom_eventarc_channel ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = "${var.function_name}-events"
}

resource "google_project_iam_member" "eventarc_publisher" {
  count = var.enable_custom_eventarc_channel ? 1 : 0

  project = var.project_id
  role    = "roles/eventarc.publisher"
  member  = "serviceAccount:${google_service_account.fn.email}"
}

# ── Source bucket + archive ───────────────────────────────────────────────────

resource "google_storage_bucket" "source" {
  project                     = var.project_id
  name                        = "${var.project_id}-${var.function_name}-source"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
}

data "archive_file" "source" {
  type        = "zip"
  output_path = "${path.root}/${var.function_name}-source.zip"
  source_dir  = var.source_dir
  excludes    = var.source_excludes
}

# Object name includes the source MD5 so any code change triggers redeployment.
resource "google_storage_bucket_object" "source" {
  name   = "${var.function_name}-${data.archive_file.source.output_md5}.zip"
  bucket = google_storage_bucket.source.name
  source = data.archive_file.source.output_path
}

# ── Cloud Function Gen 2 ──────────────────────────────────────────────────────

resource "google_cloudfunctions2_function" "fn" {
  project     = var.project_id
  location    = var.region
  name        = var.function_name
  description = var.function_description

  build_config {
    runtime     = var.runtime
    entry_point = var.entry_point

    source {
      storage_source {
        bucket = google_storage_bucket.source.name
        object = google_storage_bucket_object.source.name
      }
    }
  }

  service_config {
    service_account_email          = google_service_account.fn.email
    min_instance_count             = var.min_instance_count
    max_instance_count             = var.max_instance_count
    available_memory               = "${var.function_memory_mb}Mi"
    timeout_seconds                = var.timeout_seconds
    all_traffic_on_latest_revision = true

    environment_variables = var.environment_variables

    dynamic "secret_environment_variables" {
      for_each = var.secret_environment_variables
      content {
        key        = secret_environment_variables.value.env_var
        project_id = var.project_id
        secret     = secret_environment_variables.value.secret_id
        version    = secret_environment_variables.value.version
      }
    }
  }

  dynamic "event_trigger" {
    for_each = local.event_trigger_list
    content {
      trigger_region        = event_trigger.value.trigger_region
      event_type            = event_trigger.value.event_type
      service_account_email = google_service_account.fn.email
      retry_policy          = event_trigger.value.retry_policy

      dynamic "event_filters" {
        for_each = event_trigger.value.event_filters
        content {
          attribute = event_filters.value.attribute
          value     = event_filters.value.value
          operator  = event_filters.value.operator
        }
      }
    }
  }

  depends_on = [
    google_storage_bucket_object.source,
    google_project_iam_member.core,
    google_project_iam_member.eventarc_sa_token_creator,
  ]
}
