# Contributing

Thanks for your interest in contributing to this project. This guide covers the basics of how to get set up and submit changes.

## Getting Started

1. Fork the repository and clone your fork.
2. Install dependencies from the repository root:
   ```sh
   pnpm install
   ```
3. Create a new branch for your work:
   ```sh
   git checkout -b my-feature
   ```

## Development Workflow

### Building

From the repository root:

```sh
pnpm run build        # build all functions
```

Or target a single extension:

```sh
pnpm --filter firestore-translate-text-functions run build
```

This cleans the `lib/` directory and compiles TypeScript. The compiled output goes to `lib/` (CommonJS).

### Linting

This project uses [Biome](https://biomejs.dev/) for linting and formatting. Config is shared via the root `biome.json`; each function's `biome.json` extends it.

```sh
pnpm run lint         # check for issues
pnpm run lint:fix     # auto-fix issues
```

Please make sure your code passes linting before submitting a pull request.

### Terraform

If you're making changes to the Terraform configuration:

- Run `pnpm run tf:fmt` to format all `.tf` files.
- Run `pnpm run tf:validate` to validate all Terraform configs.
- Test your changes against a real GCP project if possible. The Terraform configuration enables APIs, creates IAM bindings, and deploys a Cloud Function, so there isn't a great way to test it in isolation.

## Adding a New Extension

Use the scaffolding CLI to generate a new extension:

```sh
pnpm run scaffold my-new-extension
```

This creates the standard structure with `function/` and `terraform/` directories, wired into the workspace. After scaffolding, run `pnpm install` to register the new package.

Follow the patterns established by `firestore-translate-text` for consistency. In particular:

- Use TypeScript with strict mode enabled (compiler options are inherited from `tsconfig.base.json`).
- Use a dedicated service account with least-privilege IAM roles.
- Expose all configuration through Terraform variables with sensible defaults.
- Include descriptions on all Terraform variables and outputs.
- Keep `typescript`, `rimraf`, and `@types/node` in each function's `devDependencies` (Cloud Build needs them during `gcp-build`).

### Shared code between functions

Cloud Build deploys each function by zipping its directory and running `npm install` from that function's `package.json` in isolation. It has no awareness of the pnpm workspace, so `workspace:` protocol dependencies will break deployment.

If you need to share code between functions, bundle it into each function at build time (e.g. with `tsup` or `esbuild`), or use `pnpm deploy` to produce a standalone directory with workspace deps resolved to real packages before zipping. Do **not** use `workspace:*` in any function's `package.json`.

## Submitting a Pull Request

1. Make sure the function compiles without errors (`pnpm run build`).
2. Make sure linting passes (`pnpm run lint`).
3. Write a clear description of what your change does and why.
4. If your change affects the Terraform configuration, note any new variables or resources.
5. Keep pull requests focused. If you have unrelated changes, submit them as separate PRs.

## Code Style

- TypeScript with strict mode.
- Biome handles formatting (2-space indent, double quotes) and linting. Shared rules live in the root `biome.json`; each function extends it.
- Prefer clear, straightforward code over clever abstractions.

## Reporting Issues

If you find a bug or have a feature request, please open a GitHub issue. Include as much context as you can -- the translation provider you're using, relevant Terraform variable values, and any error messages or logs.

## License

By contributing, you agree that your contributions will be licensed under the Apache 2.0 license.
