locals {
  required_apis = [
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "eventarc.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "firestore.googleapis.com",
    "iam.googleapis.com",
  ]

  # Matches any document within the collection (and any subcollections).
  firestore_document_filter = "${var.collection_path}/{document=**}"
}

# ── APIs ──────────────────────────────────────────────────────────────────────

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ── Project number (needed for Eventarc service agent IAM) ───────────────────

data "google_project" "project" {
  project_id = var.project_id
}

# ── Extension-specific IAM ────────────────────────────────────────────────────

resource "google_project_iam_member" "datastore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${module.cloud_function.service_account_email}"

  depends_on = [google_project_service.apis]
}

# TODO: add any additional IAM bindings or resources here

# ── Cloud Function (via shared module) ───────────────────────────────────────

module "cloud_function" {
  source = "../../modules/gcp-cloud-function"

  project_id     = var.project_id
  project_number = data.google_project.project.number
  region         = var.region

  function_name        = var.function_name
  function_description = "{{FUNCTION_DESCRIPTION}}"

  runtime     = "nodejs24"
  entry_point = "{{FUNCTION_NAME}}"
  source_dir  = "${path.module}/../function"

  min_instance_count = var.function_min_instances
  max_instance_count = var.function_max_instances
  function_memory_mb = var.function_memory_mb
  timeout_seconds    = var.function_timeout_seconds

  environment_variables = {
    COLLECTION_PATH = var.collection_path
    PROJECT_ID      = var.project_id
    LOCATION        = var.region
    # TODO: add extension-specific environment variables here
  }

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
