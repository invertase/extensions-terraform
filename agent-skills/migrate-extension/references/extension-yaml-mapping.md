# Extension YAML Field Mapping Reference

Reference for parsing `extension.yaml` fields during migration to Cloud Function + Terraform.

---

## Trigger Type Detection

### Firestore

`resources[].type` is `firebaseextensions.v1beta.function` and the resource has:

```yaml
properties:
  eventTrigger:
    eventType: providers/cloud.firestore/eventTypes/document.write
    # or: document.create, document.update, document.delete
```

Or in newer extensions, the `eventTrigger.eventType` is one of:
- `google.cloud.firestore.document.v1.written`
- `google.cloud.firestore.document.v1.created`
- `google.cloud.firestore.document.v1.updated`
- `google.cloud.firestore.document.v1.deleted`

Terraform event type to use: `google.cloud.firestore.document.v1.written`

### HTTP

`resources[].type` is `firebaseextensions.v1beta.function` and the resource has:
```yaml
properties:
  httpsTrigger: {}
```

No Eventarc trigger needed; the module creates an HTTPS endpoint.

### Pub/Sub

`resources[].type` is `firebaseextensions.v1beta.function` and the resource has:
```yaml
properties:
  eventTrigger:
    eventType: google.pubsub.topic.publish
    resource: projects/${PROJECT_ID}/topics/${param:TOPIC_NAME}
```

---

## Collection Path / Pub/Sub Topic Extraction

The `eventTrigger.resource` field often contains param references like:

```yaml
resource: projects/${PROJECT_ID}/databases/(default)/documents/${param:COLLECTION_PATH}/{document}
```

Extract the param name (e.g., `COLLECTION_PATH`) and look it up in the `params[]` list to find:
- The param's `label` → use as the Terraform variable description
- The param's `default` → use as the Terraform variable default value

For Pub/Sub:
```yaml
resource: projects/${PROJECT_ID}/topics/${param:TOPIC_NAME}
```

---

## Params → Terraform Variables

Each param in `params[]` becomes a Terraform variable. Mapping by `type`:

| Param type   | Terraform type | Notes                                                   |
|--------------|----------------|---------------------------------------------------------|
| `string`     | `string`       | Use `default` if provided; omit `default` if required   |
| `select`     | `string`       | Use `default`; add `validation` block with allowed values if it's a small fixed set |
| `multiSelect`| `string`       | Store as comma-separated string; use `default` joined with commas |
| `secret`     | `string`       | Add `sensitive = true`; goes in Secret Manager, NOT env vars |

Example for `string` param:
```yaml
# extension.yaml
- param: LANGUAGES
  label: Target languages
  description: Comma-separated list of languages to translate into.
  type: string
  default: en,es,fr
  required: true
```

Becomes in `variables.tf`:
```hcl
variable "languages" {
  description = "Comma-separated list of languages to translate into."
  type        = string
  default     = "en,es,fr"
}
```

And in `main.tf` `environment_variables`:
```hcl
LANGUAGES = var.languages
```

---

## Secret Params → Secret Manager

For `type: secret` params:

```yaml
- param: API_KEY
  label: API Key
  type: secret
```

Creates three resources in `main.tf`:

```hcl
resource "google_secret_manager_secret" "api_key" {
  project   = var.project_id
  secret_id = "${var.function_name}-api-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "api_key" {
  secret      = google_secret_manager_secret.api_key.id
  secret_data = var.api_key
}

resource "google_secret_manager_secret_iam_member" "api_key_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.cloud_function.service_account_email}"
}
```

Then in the module call's `secret_environment_variables`:
```hcl
secret_environment_variables = [
  {
    env_var   = "API_KEY"
    secret_id = google_secret_manager_secret.api_key.secret_id
    version   = "latest"
  }
]
```

And add `secretmanager.googleapis.com` to `local.required_apis`.

---

## APIs → `local.required_apis`

The extension's `apis[]` list maps directly to `local.required_apis`. The base set already included by templates:

```
cloudfunctions.googleapis.com
cloudbuild.googleapis.com
eventarc.googleapis.com
run.googleapis.com
artifactregistry.googleapis.com
firestore.googleapis.com   (firestore trigger only)
iam.googleapis.com
```

Add any additional APIs from `apis[].apiName`. Common ones:

| Extension API                    | Terraform entry                        |
|----------------------------------|----------------------------------------|
| `translate.googleapis.com`       | `"translate.googleapis.com"`           |
| `vision.googleapis.com`          | `"vision.googleapis.com"`              |
| `aiplatform.googleapis.com`      | `"aiplatform.googleapis.com"`          |
| `secretmanager.googleapis.com`   | `"secretmanager.googleapis.com"`       |
| `storage.googleapis.com`         | `"storage.googleapis.com"`             |
| `pubsub.googleapis.com`          | `"pubsub.googleapis.com"`              |
| `storage-component.googleapis.com` | `"storage-component.googleapis.com"` |

---

## Roles → IAM Bindings

Each entry in `roles[]` becomes a `google_project_iam_member` resource:

```yaml
roles:
  - role: roles/datastore.user
    reason: Read and write to Firestore.
  - role: roles/storage.objectAdmin
    reason: Read and write objects in Cloud Storage.
```

Becomes:
```hcl
resource "google_project_iam_member" "datastore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${module.cloud_function.service_account_email}"

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "storage_object_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${module.cloud_function.service_account_email}"

  depends_on = [google_project_service.apis]
}
```

Use a descriptive Terraform resource name derived from the role (e.g., `roles/datastore.user` → `datastore_user`, `roles/storage.objectAdmin` → `storage_object_admin`).

---

## Firebase Functions v1 → v2 Migration

### Import changes

| v1 (original)                                      | v2 (migrated)                                         |
|----------------------------------------------------|-------------------------------------------------------|
| `import * as functions from "firebase-functions"` | `import { onDocumentWritten } from "firebase-functions/v2/firestore"` |
| `import { firestore } from "firebase-functions"`  | `import { onDocumentWritten } from "firebase-functions/v2/firestore"` |
| `import { https } from "firebase-functions"`       | `import { onRequest } from "firebase-functions/v2/https"`             |
| `import { pubsub } from "firebase-functions"`      | `import { onMessagePublished } from "firebase-functions/v2/pubsub"`   |

### Handler signature changes

**Firestore (document.write/create/update/delete):**

```typescript
// v1
export const myFn = functions.firestore
  .document("collection/{docId}")
  .onWrite(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const docId = context.params.docId;
  });

// v2
export const myFn = onDocumentWritten("collection/{docId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  const docId = event.params.docId;
});
```

**HTTP:**

```typescript
// v1
export const myFn = functions.https.onRequest((req, res) => { ... });

// v2
export const myFn = onRequest((req, res) => { ... });
```

**Pub/Sub:**

```typescript
// v1
export const myFn = functions.pubsub.topic("my-topic").onPublish((message) => {
  const data = message.json;
});

// v2
export const myFn = onMessagePublished("my-topic", (event) => {
  const data = event.data.message.json;
});
```

### Configuration changes

v1 used `functions.config().extension.*` for configuration. In v2, all config comes from environment variables:

```typescript
// v1
const config = functions.config().extension;
const lang = config.languages;

// v2 (env vars set via Terraform)
const lang = process.env.LANGUAGES;
```

### Common removals

- Remove `export const processCreatedDoc = ...` (backfill task exports) — not needed
- Remove `functions.tasks.taskQueue()` exports unless tasks are explicitly needed
- Remove any imports of `firebase-admin/extensions` (for backfill)
- Remove lifecycle event publishing unless the extension specifically needs it

---

## Events → Custom Eventarc Channel

If extension.yaml has an `events[]` block, the extension publishes custom lifecycle events. Set:

```hcl
enable_custom_eventarc_channel = true
```

And add to `environment_variables`:
```hcl
EVENTARC_CHANNEL    = module.cloud_function.custom_eventarc_channel
EXT_SELECTED_EVENTS = join(",", var.custom_event_types)
```

And add a variable for `custom_event_types`:
```hcl
variable "custom_event_types" {
  description = "List of custom event types to publish to Eventarc."
  type        = list(string)
  default     = []
}

variable "enable_custom_events" {
  description = "Whether to create a custom Eventarc channel for lifecycle events."
  type        = bool
  default     = false
}
```

---

## Raw GitHub URL Patterns

For fetching source files from firebase/extensions:

```
Base URL: https://raw.githubusercontent.com/{owner}/{repo}/main/{extension-name}/

extension.yaml:    {base}extension.yaml
function source:   {base}functions/src/index.ts
package.json:      {base}functions/package.json
```

Some extensions have their source in `{extension-name}/functions/lib/` (compiled JS) — prefer `src/` (TypeScript source). If `src/index.ts` 404s, try `functions/index.js`.

---

## Always-Set Environment Variables

These are always set regardless of extension type (include in every `environment_variables` map):

```hcl
PROJECT_ID = var.project_id
LOCATION   = var.region
```

These are required because:
- `PROJECT_ID`: Cloud Run doesn't automatically expose the project ID to the function
- `LOCATION`: Required by Genkit Vertex AI plugin and other GCP client libraries for regional configuration
