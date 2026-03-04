import { readdirSync, mkdirSync, writeFileSync, readFileSync } from "node:fs";
import { join, relative, dirname } from "node:path";
import type { ScaffoldContext } from "./types.ts";

const TEMPLATES_DIR = join(import.meta.dirname, "../templates");
const REPO_ROOT = join(import.meta.dirname, "../..");

/**
 * Builds the token replacement map from the scaffold context.
 * All tokens use the {{TOKEN}} convention.
 */
function buildTokenMap(ctx: ScaffoldContext): Record<string, string> {
  return {
    "{{EXTENSION_NAME}}": ctx.extensionName,
    "{{FUNCTION_NAME}}": ctx.functionName,
    "{{FUNCTION_DESCRIPTION}}": ctx.description,
    "{{COLLECTION_PATH}}": ctx.collectionPath ?? "collection",
    "{{PUBSUB_TOPIC}}": ctx.pubsubTopic ?? "topic",
    "{{YEAR}}": ctx.year,
  };
}

/** Replaces all tokens in a string. */
function interpolate(content: string, tokens: Record<string, string>): string {
  let result = content;
  for (const [token, value] of Object.entries(tokens)) {
    result = result.replaceAll(token, value);
  }
  return result;
}

/** Recursively lists all files under a directory. */
function walkDir(dir: string): string[] {
  const entries = readdirSync(dir, { withFileTypes: true });
  const files: string[] = [];
  for (const entry of entries) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...walkDir(full));
    } else {
      files.push(full);
    }
  }
  return files;
}

/** Copies a template directory into outDir, interpolating tokens in file contents. */
function copyTemplateDir(
  templateDir: string,
  outDir: string,
  tokens: Record<string, string>
): void {
  for (const file of walkDir(templateDir)) {
    const rel = relative(templateDir, file);
    const dest = join(outDir, rel);
    mkdirSync(dirname(dest), { recursive: true });
    const content = readFileSync(file, "utf8");
    writeFileSync(dest, interpolate(content, tokens));
  }
}

/**
 * Scaffolds a new extension directory from templates.
 * Returns the absolute path of the created directory.
 */
export function scaffold(ctx: ScaffoldContext): string {
  const outDir = join(REPO_ROOT, ctx.extensionName);
  const tokens = buildTokenMap(ctx);

  for (const dir of [
    join(TEMPLATES_DIR, "shared"),
    join(TEMPLATES_DIR, "triggers", ctx.triggerType),
  ]) {
    copyTemplateDir(dir, outDir, tokens);
  }

  return outDir;
}
