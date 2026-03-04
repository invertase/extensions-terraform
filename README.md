# Extensions Terraform

Self-managed Google Cloud Functions that replicate [Firebase Extensions](https://extensions.dev) functionality, deployed and managed entirely through Terraform.

This approach gives you full control over the infrastructure -- you own the Cloud Function, the IAM bindings, and the configuration, rather than relying on the Firebase Extensions framework.

## Available Extensions

### [firestore-translate-text](./firestore-translate-text)

A Cloud Function that listens for writes to a Firestore collection and automatically translates text fields into one or more target languages.

**Supported translation providers:**

- **Cloud Translation API** (default) -- Google's production translation service
- **Gemini via Vertex AI** -- uses Genkit with the Vertex AI plugin
- **Gemini via Google AI** -- uses Genkit with the Google AI plugin (requires an API key)

**Key features:**

- Translates on document create and update, cleans up on delete
- Supports both single string fields and structured object fields
- Per-document language overrides via a configurable field
- Skips redundant translations when the input hasn't changed
- Publishes Eventarc events for downstream integrations
- Configurable scaling (min/max instances, memory, timeout)

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (`gcloud`)
- [Bun](https://bun.sh) >= 1.0 (for the CLI and function development)
- A Google Cloud project with billing enabled
- A Firestore database in the target project

## Quick Start

1. **Clone the repository:**

   ```sh
   git clone <repo-url>
   cd extensions-terraform
   ```

2. **Navigate to the Terraform directory for the extension you want to deploy:**

   ```sh
   cd firestore-translate-text/terraform
   ```

3. **Create a `terraform.tfvars` file** from the example:

   ```sh
   cp terraform.tfvars.example terraform.tfvars
   ```

   Edit it with your project ID and any other overrides. See [`variables.tf`](./firestore-translate-text/terraform/variables.tf) for all available options.

4. **Initialize and apply:**

   ```sh
   terraform init
   terraform plan
   terraform apply
   ```

   Terraform will enable the required APIs, create a dedicated service account with least-privilege IAM roles, upload the function source, and deploy the Cloud Function with a Firestore event trigger.

5. **Test it out** by writing a document to the configured collection:

   ```sh
   gcloud firestore documents create \
     --collection=translations \
     --document-id=hello \
     --data='{"input": "Hello, world!"}'
   ```

   After a few seconds, the document will be updated with a `translated` field containing translations for each configured language.

## Configuration Reference

Each extension's Terraform variables are documented in its `variables.tf`. Here are the key variables for `firestore-translate-text`:

| Variable | Default | Description |
|---|---|---|
| `project_id` | (required) | GCP project ID |
| `region` | `us-central1` | GCP region for the function |
| `collection_path` | `translations` | Firestore collection to watch |
| `input_field_name` | `input` | Document field containing text to translate |
| `output_field_name` | `translated` | Document field where translations are written |
| `languages` | `en,es,de,fr` | Comma-separated ISO 639-1 language codes |
| `translation_provider` | `translate` | One of: `translate`, `gemini-googleai`, `gemini-vertexai` |
| `gemini_model` | `gemini-2.5-flash` | Model name when using a Gemini provider |
| `function_memory_mb` | `256` | Memory allocation in MB |
| `function_timeout_seconds` | `60` | Function timeout |
| `function_min_instances` | `0` | Minimum instances (set > 0 to avoid cold starts) |
| `function_max_instances` | `10` | Maximum instances |

## Adding a New Extension

Use the CLI to scaffold a new extension with all the boilerplate in place:

```sh
cd cli && bun install
bun src/index.ts init my-new-extension
```

The CLI prompts for a trigger type (Firestore, HTTP, or Pub/Sub), entry point name, and any trigger-specific configuration, then generates a complete skeleton:

```
my-new-extension/
  function/          # Cloud Function source stub (TypeScript)
    src/index.ts     # Trigger handler ready to implement
    package.json
    tsconfig.json
    biome.json
  terraform/         # Terraform configuration wired to the shared module
    main.tf
    variables.tf
    outputs.tf
    providers.tf
    terraform.tfvars.example
```

After scaffolding:

```sh
cd my-new-extension/function && bun install
cd ../terraform && terraform init && terraform validate
```

## Project Structure

```
extensions-terraform/
  cli/                     # Scaffolding CLI (Bun / TypeScript)
    src/
      index.ts             # Entry point
      prompts.ts           # Interactive prompts
      scaffold.ts          # Template walking and token interpolation
      types.ts             # Shared types
    templates/
      shared/              # Files copied into every extension
      triggers/
        firestore/         # Firestore document write templates
        http/              # HTTP / callable templates
        pubsub/            # Pub/Sub templates
  modules/
    gcp-cloud-function/    # Shared Terraform module
      main.tf              # Service account, IAM, GCS source, Cloud Function
      variables.tf         # Module interface
      outputs.tf           # Exported values
  firestore-translate-text/
    function/              # Cloud Function source (TypeScript)
      src/
        index.ts           # Entry point and Firestore trigger
        config.ts          # Environment variable configuration
        translate/         # Translation logic (strategy pattern)
        logs/              # Structured logging
      package.json
      tsconfig.json
    terraform/             # Extension-specific Terraform
      main.tf              # APIs, domain IAM, Secret Manager, module call
      variables.tf         # Input variables
      outputs.tf           # Output values
      providers.tf         # Provider configuration
```

## Working on the Function Code

If you want to modify the Cloud Function source:

```sh
cd firestore-translate-text/function
bun install
bun run build
```

The build compiles TypeScript from `src/` to `lib/`. When you run `terraform apply`, the source is zipped and uploaded to a GCS bucket. The object name includes a content hash, so any code change triggers a redeployment.

## License

Apache 2.0
