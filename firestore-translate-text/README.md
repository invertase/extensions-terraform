# Firestore Translate Text

A self-managed Cloud Function that automatically translates strings written to Firestore into multiple languages, using either the Cloud Translation API or Gemini (via Vertex AI or Google AI).

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  terraform apply                                                 │
│                                                                  │
│  1. Zips function/ source (excludes lib/, node_modules/)         │
│  2. Uploads zip to GCS bucket                                    │
│  3. Deploys google_cloudfunctions2_function                      │
│     └─ Cloud Functions builds the source on GCP infra:           │
│        • npm install                                             │
│        • npm run gcp-build  →  tsc (compiles TypeScript)         │
│  4. Creates Eventarc trigger on Firestore document.written       │
│  5. Provisions IAM, service account, and (optionally) secrets    │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│  Runtime                                                         │
│                                                                  │
│  Firestore write (create/update)                                 │
│       ↓                                                          │
│  Eventarc trigger (document.written)                             │
│       ↓                                                          │
│  Cloud Function (Node.js 24)                                     │
│       ↓                                                          │
│  Translation provider:                                           │
│    • "translate"        → Cloud Translation API v2               │
│    • "gemini-vertexai"  → Genkit + Vertex AI                     │
│    • "gemini-googleai"  → Genkit + Google AI (requires API key)  │
│       ↓                                                          │
│  Writes translations back to the same Firestore document         │
└──────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
firestore-translate-text/
├── function/               # Cloud Function source (TypeScript)
│   ├── src/
│   │   ├── index.ts        # Entry point — onDocumentWritten handler
│   │   ├── config.ts       # Runtime config from environment variables
│   │   ├── events.ts       # Eventarc event publishing
│   │   ├── validators.ts   # Input validation
│   │   ├── translate/      # Translation logic
│   │   │   ├── common.ts   # Translator classes and TranslationService
│   │   │   ├── translateSingle.ts
│   │   │   ├── translateMultiple.ts
│   │   │   └── translateDocument.ts
│   │   └── logs/           # Structured logging
│   ├── tsconfig.json
│   ├── biome.json          # Linter/formatter config
│   └── package.json
└── terraform/              # Infrastructure as Code
    ├── main.tf             # Function, IAM, GCS, Eventarc, secrets
    ├── variables.tf        # Input variables
    ├── outputs.tf          # Terraform outputs
    └── providers.tf        # Provider requirements
```

## Prerequisites

- Terraform >= 1.5.0
- A GCP project with billing enabled
- `gcloud` CLI authenticated

## Usage

```hcl
module "firestore_translate" {
  source = "./firestore-translate-text/terraform"

  project_id      = "my-gcp-project"
  region          = "us-central1"
  collection_path = "translations"
  languages       = "en,es,de,fr"

  # Optional: use Gemini instead of Cloud Translation API
  # translation_provider = "gemini-vertexai"
  # gemini_model         = "gemini-2.5-flash"
}
```

```bash
terraform init
terraform plan
terraform apply
```

## Variables

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | (required) |
| `region` | GCP region | `us-central1` |
| `collection_path` | Firestore collection to watch | `translations` |
| `input_field_name` | Document field containing source text | `input` |
| `output_field_name` | Document field for translated output | `translated` |
| `languages` | Comma-separated ISO-639-1 codes | `en,es,de,fr` |
| `languages_field_name` | Per-document language override field | `""` |
| `translation_provider` | `translate`, `gemini-googleai`, or `gemini-vertexai` | `translate` |
| `gemini_model` | Gemini model name | `gemini-2.5-flash` |
| `google_ai_api_key` | API key for `gemini-googleai` provider | `""` |
| `enable_custom_events` | Enable Eventarc lifecycle events | `false` |
| `custom_event_types` | Event types to publish | all four lifecycle events |
| `function_name` | Cloud Function resource name | `translateText` |
| `function_min_instances` | Minimum instances | `0` |
| `function_max_instances` | Maximum instances | `10` |
| `function_memory_mb` | Memory in MB | `256` |
| `function_timeout_seconds` | Timeout in seconds | `60` |

## Custom Events

The function can publish lifecycle events via Eventarc. This is opt-in:

```hcl
module "firestore_translate" {
  source = "./firestore-translate-text/terraform"

  # ...
  enable_custom_events = true
}
```

When enabled, Terraform provisions an Eventarc channel and the function publishes these events:

| Event | When |
|---|---|
| `onStart` | Translation begins |
| `onError` | Translation fails |
| `onSuccess` | A document is translated successfully |
| `onCompletion` | Translation run finishes (success or failure) |

You can create Eventarc triggers on this channel to route these events to other Cloud Run services, Workflows, or Pub/Sub topics.

## Development

```bash
cd function
npm install
npm run build       # clean + tsc
npm run lint        # biome check
npm run lint:fix    # biome check --write
```
