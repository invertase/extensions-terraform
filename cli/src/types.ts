export type TriggerType = "firestore" | "http" | "pubsub";

export interface ScaffoldContext {
  /** Kebab-case slug, e.g. "firestore-send-email" */
  extensionName: string;
  /** camelCase entry point, e.g. "sendEmail" */
  functionName: string;
  /** Human-readable description */
  description: string;
  triggerType: TriggerType;
  /** Firestore collection path, only set when triggerType === "firestore" */
  collectionPath?: string;
  /** Pub/Sub topic name, only set when triggerType === "pubsub" */
  pubsubTopic?: string;
  /** Current year for license headers */
  year: string;
}
