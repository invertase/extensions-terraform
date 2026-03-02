# Contributing

Thanks for your interest in contributing to this project. This guide covers the basics of how to get set up and submit changes.

## Getting Started

1. Fork the repository and clone your fork.
2. Create a new branch for your work:
   ```sh
   git checkout -b my-feature
   ```
3. Install dependencies for the extension you're working on:
   ```sh
   cd firestore-translate-text/function
   npm install
   ```

## Development Workflow

### Building

```sh
npm run build
```

This cleans the `lib/` directory and compiles TypeScript. The compiled output goes to `lib/` (CommonJS).

### Linting

This project uses [Biome](https://biomejs.dev/) for linting and formatting.

```sh
npm run lint          # check for issues
npm run lint:fix      # auto-fix issues
```

Please make sure your code passes linting before submitting a pull request.

### Terraform

If you're making changes to the Terraform configuration:

- Run `terraform fmt` to format your `.tf` files.
- Run `terraform validate` to catch syntax errors.
- Test your changes against a real GCP project if possible. The Terraform configuration enables APIs, creates IAM bindings, and deploys a Cloud Function, so there isn't a great way to test it in isolation.

## Adding a New Extension

Each extension lives in its own top-level directory with the following structure:

```
my-new-extension/
  function/          # Cloud Function source code
    src/
    package.json
    tsconfig.json
  terraform/         # Terraform IaC
    main.tf
    variables.tf
    outputs.tf
    providers.tf
```

Follow the patterns established by `firestore-translate-text` for consistency. In particular:

- Use TypeScript with strict mode enabled.
- Use a dedicated service account with least-privilege IAM roles.
- Expose all configuration through Terraform variables with sensible defaults.
- Include descriptions on all Terraform variables and outputs.

## Submitting a Pull Request

1. Make sure the function compiles without errors (`npm run build`).
2. Make sure linting passes (`npm run lint`).
3. Write a clear description of what your change does and why.
4. If your change affects the Terraform configuration, note any new variables or resources.
5. Keep pull requests focused. If you have unrelated changes, submit them as separate PRs.

## Code Style

- TypeScript with strict mode.
- Biome handles formatting (2-space indent, double quotes) and linting. Check the `biome.json` in each function directory for the full config.
- Prefer clear, straightforward code over clever abstractions.

## Reporting Issues

If you find a bug or have a feature request, please open a GitHub issue. Include as much context as you can -- the translation provider you're using, relevant Terraform variable values, and any error messages or logs.

## License

By contributing, you agree that your contributions will be licensed under the Apache 2.0 license.
