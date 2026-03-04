import { readdirSync } from "node:fs";
import { join, relative } from "node:path";
import { gatherContext } from "./prompts.ts";
import { scaffold } from "./scaffold.ts";

function listFilesRelative(dir: string, base: string): string[] {
  const entries = readdirSync(dir, { withFileTypes: true });
  const files: string[] = [];
  for (const entry of entries) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...listFilesRelative(full, base));
    } else {
      files.push(relative(base, full));
    }
  }
  return files.sort();
}

async function main() {
  const [, , command, nameArg] = process.argv;

  if (command !== "init") {
    console.error(`Unknown command: ${command ?? "(none)"}`);
    console.error("Usage: bun cli/src/index.ts init [extension-name]");
    process.exit(1);
  }

  const ctx = await gatherContext(nameArg);
  const outDir = scaffold(ctx);

  const files = listFilesRelative(outDir, outDir);
  console.log(`\n✓ Created ${ctx.extensionName}/`);
  for (const f of files) {
    console.log(`  ${f}`);
  }

  console.log(`
Next steps:
  pnpm install
  cd ${ctx.extensionName}/terraform && terraform init && terraform validate`);
}

main().catch((err: unknown) => {
  console.error(err);
  process.exit(1);
});
