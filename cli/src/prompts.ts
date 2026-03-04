import { input, select } from "@inquirer/prompts";
import type { ScaffoldContext, TriggerType } from "./types.ts";

/**
 * Derives a camelCase function name from the last segment of a kebab-case slug.
 * e.g. "firestore-send-email" → "sendEmail"
 */
function deriveEntryPoint(extensionName: string): string {
  const segments = extensionName.split("-");
  // Drop a leading trigger-type prefix segment if present (firestore/http/pubsub)
  const meaningful =
    segments.length > 1 &&
    ["firestore", "http", "pubsub"].includes(segments[0])
      ? segments.slice(1)
      : segments;
  return meaningful
    .map((s, i) =>
      i === 0 ? s.charAt(0).toLowerCase() + s.slice(1) : s.charAt(0).toUpperCase() + s.slice(1)
    )
    .join("");
}

export async function gatherContext(nameArg?: string): Promise<ScaffoldContext> {
  const extensionName =
    nameArg ??
    (await input({
      message: "Extension name (slug):",
      validate: (v) =>
        /^[a-z][a-z0-9-]+$/.test(v)
          ? true
          : "Must be a lowercase slug (e.g. firestore-send-email)",
    }));

  const triggerType = await select<TriggerType>({
    message: "Trigger type:",
    choices: [
      { name: "Firestore document write", value: "firestore" },
      { name: "HTTP / callable", value: "http" },
      { name: "Pub/Sub", value: "pubsub" },
    ],
  });

  const functionName = await input({
    message: "Entry point name:",
    default: deriveEntryPoint(extensionName),
  });

  const description = await input({
    message: "Short description:",
    default: `Cloud Function for ${extensionName}`,
  });

  let collectionPath: string | undefined;
  if (triggerType === "firestore") {
    collectionPath = await input({
      message: "Default collection path:",
      default: extensionName.replace(/^firestore-/, ""),
    });
  }

  let pubsubTopic: string | undefined;
  if (triggerType === "pubsub") {
    pubsubTopic = await input({
      message: "Default Pub/Sub topic name:",
      default: extensionName.replace(/^pubsub-/, ""),
    });
  }

  return {
    extensionName,
    functionName,
    description,
    triggerType,
    collectionPath,
    pubsubTopic,
    year: new Date().getFullYear().toString(),
  };
}
