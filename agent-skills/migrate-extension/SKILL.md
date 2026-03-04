---
name: migrate-extension
description: Migrates a Firebase Extension to a self-managed Cloud Function with Terraform. Takes a GitHub repo URL and extension name, fetches extension.yaml, scaffolds the structure, writes a migration plan for approval, then executes. Use when porting a Firebase Extension to this repo's Terraform pattern.
compatibility: Designed for Claude Code. Requires internet access to fetch extension.yaml from GitHub.
allowed-tools: WebFetch Bash Read Write Edit Glob Grep
---

# migrate-extension Skill

Migrates a Firebase Extension to a self-managed Cloud Function + Terraform, following the patterns established in `firestore-translate-text/`.

**Usage:** `migrate-extension <github-repo-url> <extension-name>`

Example: `migrate-extension https://github.com/firebase/extensions firestore-send-email`

---

## Before Starting

Read `firestore-translate-text/` as the canonical example. Specifically:
- `firestore-translate-text/terraform/main.tf` — IAM, secrets, module call pattern
- `firestore-translate-text/terraform/variables.tf` — variable conventions
- `firestore-translate-text/terraform/outputs.tf` — output conventions
- `firestore-translate-text/function/src/index.ts` — v2 function pattern

Also check `modules/gcp-cloud-function/` for the shared module interface.

---

## Step 1: Fetch and Confirm extension.yaml

Construct the raw GitHub URL:
```
https://raw.githubusercontent.com/{owner}/{repo}/main/{extension-name}/extension.yaml
```

For example, `https://github.com/firebase/extensions` + `firestore-send-email` becomes:
```
https://raw.githubusercontent.com/firebase/extensions/main/firestore-send-email/extension.yaml
```

Fetch with WebFetch and parse. Present a summary to the user:
- Extension name and display name
- Description
- Trigger type (firestore / http / pubsub)
- Resources (Cloud Functions listed)
- Params (variables the user configures)
- APIs required
- IAM roles requested

**Checkpoint: Ask the user to confirm this is the correct extension before continuing.**

---

## Step 2: Analyze the Extension

Parse extension.yaml using the [field mapping reference](references/extension-yaml-mapping.md):

1. **Trigger type** — detect from `resources[].type` or `eventTrigger.eventType`
2. **Entry point name** — from `resources[0].name`, converted to camelCase
3. **Collection path param** — find the param that maps to the Firestore collection (look for params whose description mentions "collection" or whose default looks like a path). Extract the default value.
4. **Pub/Sub topic param** — find the param that maps to the topic (for pubsub triggers). Extract the default.
5. **Extension-specific APIs** — from `apis[]` (beyond the base set already in templates)
6. **IAM roles** — from `roles[]`, each becomes a `google_project_iam_member` resource
7. **Params → Terraform variables** — map each param to a variable. Secret params need Secret Manager.
8. **Params → env vars** — determine which params become `environment_variables` vs `secret_environment_variables`
9. **Events** — if `events[]` is present, set `enable_custom_eventarc_channel = true`

---

## Step 3: Scaffold

Run the scaffold via an inline Bun script to bypass interactive prompts. First `pwd` to confirm you're in the repo root:

```bash
cd /path/to/repo && bun -e "
import { scaffold } from './cli/src/scaffold.ts';
scaffold({
  extensionName: 'EXTENSION_NAME',
  functionName: 'FUNCTION_NAME_CAMEL_CASE',
  description: 'DESCRIPTION FROM EXTENSION YAML',
  triggerType: 'firestore',  // or 'http' or 'pubsub'
  collectionPath: 'DEFAULT_COLLECTION_PATH',  // firestore only
  pubsubTopic: 'DEFAULT_TOPIC',               // pubsub only
  year: '2025',
});
"
```

This creates the directory structure at `{extension-name}/` with terraform and function subdirectories.

---

## Step 4: Fetch Original Source Files

Try to fetch from the original extension repo:
- `https://raw.githubusercontent.com/{owner}/{repo}/main/{extension-name}/functions/src/index.ts`
- `https://raw.githubusercontent.com/{owner}/{repo}/main/{extension-name}/functions/package.json`

If available, use as the basis for the migrated function. Note all v1→v2 adaptations required (see reference doc).

If not available (404), note that the function source will need to be written from scratch based on the extension's description.

---

## Step 5: Write plan.md

Create `{extension-name}/plan.md` with a complete migration plan:

```markdown
# Migration Plan: {extension-name}

## Extension Summary
- Display name: ...
- Description: ...
- Trigger: ...

## Terraform Changes

### APIs to add to `local.required_apis`
- (list any APIs from `apis[]` beyond the base set)

### IAM Bindings
- (list each role from `roles[]` as a `google_project_iam_member` resource)

### Environment Variables
- (list each param → env var mapping)

### Secret Manager Resources
- (list each secret param → secret resource)

### New Variables (`variables.tf`)
- (list each new variable: name, type, description, default)

## Function Source Adaptations

### v1 → v2 Migration
- (list specific import changes, handler signature changes)

### Logic Changes
- (list any logic that needs updating beyond import/signature)

### Dependencies
- (list packages to add/update in package.json)

## Migration Decisions
- (explain any non-obvious choices)

## Reference
- See `firestore-translate-text/` for the canonical pattern this migration follows.
```

---

## Step 6: Approval Checkpoint

**Show the contents of plan.md to the user and ask for approval before making any file changes.**

Do not proceed to Step 7 until the user explicitly approves. If they request changes, update plan.md and re-show it.

---

## Step 7: Execute (After Approval)

### 7a. Check v2 trigger support

Before writing any function source, verify that the trigger type used by this extension is supported in `firebase-functions/v2`. Do this by checking the live source:

1. Fetch `https://raw.githubusercontent.com/firebase/firebase-functions/master/src/v2/index.ts` — lists all exported v2 provider modules
2. For the specific trigger the extension uses, fetch the relevant provider file (e.g. `src/v2/providers/identity.ts`) and check what's exported
3. If the trigger isn't found in v2 exports, search for an open issue confirming the gap:
   - Web search: `site:github.com/firebase/firebase-functions "{trigger name}" v2 not supported`

If the trigger is **not yet in v2**: keep v1 imports, add a `// TODO: migrate to v2 once supported — see <issue URL>` comment in the source, and note it in plan.md.

### 7b. Write function source

Write the adapted function source to `{extension-name}/function/src/index.ts`.

For triggers that are supported in v2, apply all adaptations from the reference doc:
- Update imports from `firebase-functions` to `firebase-functions/v2/{provider}`
- Update handler signatures
- Always use `nodejs24` runtime
- Remove any backfill/migration helpers not needed for a clean deploy

### 7c. Update `terraform/main.tf`

Edit the scaffolded `main.tf` to add:
- Extension-specific APIs to `local.required_apis`
- IAM bindings (`google_project_iam_member` resources)
- Secret Manager resources (for any secret params)
- Full `environment_variables` map (all params + PROJECT_ID + LOCATION)
- `secret_environment_variables` (for secret params)
- Any conditional logic needed (e.g., feature flags like `translation_provider`)

Follow the `firestore-translate-text/terraform/main.tf` pattern exactly.

### 7d. Update `terraform/variables.tf`

Add all extension-specific variables:
- One variable per param from extension.yaml
- Include type, description, and default (from param's `default` field)
- Secret params: `type = string`, `sensitive = true`

### 7e. Update `terraform/terraform.tfvars.example`

Add example values for all new variables. Use sensible defaults or placeholder strings like `"your-value-here"`.

### 7f. Update `function/package.json`

Replace the dependencies in the scaffolded `package.json` with those from the original extension's `functions/package.json`.

**Always upgrade to Node 24-compatible versions** — do not pin to the original's exact versions. Use `"latest"` or a modern semver range like `"^X.Y.Z"` and resolve actual versions with `bun info {package}` if needed.

Ensure `engines.node` is set to `"24"` and `gcp-build` script is present (`"gcp-build": "bun run build"`).

### 7g. Update plan.md

Add a brief "Execution Summary" section at the bottom of `plan.md` noting what was done, any deviations from the plan, and any manual TODOs left in the files.

---

## Step 8: Report Next Steps

After execution, report what was created and provide next steps:

```
Migration complete! Created {extension-name}/ with:
  - function/src/index.ts  (adapted from original)
  - terraform/main.tf
  - terraform/variables.tf
  - terraform/outputs.tf
  - terraform/providers.tf
  - terraform/terraform.tfvars.example
  - function/package.json

Next steps:
  cd {extension-name}/function && bun install
  cd ../{extension-name}/terraform && terraform init && terraform validate

Then deploy:
  terraform apply -var="project_id=YOUR_PROJECT_ID"
```

Note any manual TODOs that were left in the files (things that couldn't be fully automated). The `plan.md` remains in the directory as a record of the migration decisions.
