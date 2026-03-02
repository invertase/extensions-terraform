/*
 * Copyright 2019 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

import config from "./config";
import * as logs from "./logs";
import * as validators from "./validators";
import * as events from "./events";
import {
  translateDocument,
  extractLanguages,
  updateTranslations,
  extractInput,
} from "./translate";

enum ChangeType {
  CREATE,
  DELETE,
  UPDATE,
}

// Initialize the Firebase Admin SDK
admin.initializeApp();
events.setupEventChannel();

logs.init(config);

export const fstranslate = onDocumentWritten(
  `${process.env.COLLECTION_PATH}/{documentId}`,
  async (event): Promise<void> => {
    const change = event.data;
    if (!change) return;

    logs.start(config);
    await events.recordStartEvent({ event });
    const { languages, inputFieldName, outputFieldName } = config;

    if (validators.fieldNamesMatch(inputFieldName, outputFieldName)) {
      logs.fieldNamesNotDifferent();
      await events.recordCompletionEvent({ event });
      return;
    }
    if (
      validators.fieldNameIsTranslationPath(
        inputFieldName,
        outputFieldName,
        languages
      )
    ) {
      logs.inputFieldNameIsOutputPath();
      await events.recordCompletionEvent({ event });
      return;
    }

    const changeType = getChangeType(change);

    try {
      switch (changeType) {
        case ChangeType.CREATE:
          await handleCreateDocument(change.after);
          break;
        case ChangeType.DELETE:
          handleDeleteDocument();
          break;
        case ChangeType.UPDATE:
          await handleUpdateDocument(change.before, change.after);
          break;
      }

      logs.complete();
    } catch (err) {
      logs.error(err instanceof Error ? err : new Error(String(err)));
      await events.recordErrorEvent(err instanceof Error ? err : new Error(String(err)));
    }
    await events.recordCompletionEvent({ event });
  }
);

const getChangeType = (change: {
  before: admin.firestore.DocumentSnapshot;
  after: admin.firestore.DocumentSnapshot;
}): ChangeType => {
  if (!change.after.exists) {
    return ChangeType.DELETE;
  }
  if (!change.before.exists) {
    return ChangeType.CREATE;
  }
  return ChangeType.UPDATE;
};

const handleCreateDocument = async (
  snapshot: admin.firestore.DocumentSnapshot
): Promise<void> => {
  const input = extractInput(snapshot);
  if (input) {
    logs.documentCreatedWithInput();
    await translateDocument(snapshot);
  } else {
    logs.documentCreatedNoInput();
  }
};

const handleDeleteDocument = (): void => {
  logs.documentDeleted();
};

const handleUpdateDocument = async (
  before: admin.firestore.DocumentSnapshot,
  after: admin.firestore.DocumentSnapshot
): Promise<void> => {
  const inputBefore = extractInput(before);
  const inputAfter = extractInput(after);

  const languagesBefore = extractLanguages(before);
  const languagesAfter = extractLanguages(after);

  // If previous and updated documents have no input, skip.
  if (inputBefore === undefined && inputAfter === undefined) {
    logs.documentUpdatedNoInput();
    return;
  }

  // If updated document has no string or object input, delete any existing translations.
  if (typeof inputAfter !== "string" && typeof inputAfter !== "object") {
    await updateTranslations(after, admin.firestore.FieldValue.delete());
    logs.documentUpdatedDeletedInput();
    return;
  }

  if (
    JSON.stringify(inputBefore) === JSON.stringify(inputAfter) &&
    JSON.stringify(languagesBefore) === JSON.stringify(languagesAfter)
  ) {
    logs.documentUpdatedUnchangedInput();
  } else {
    logs.documentUpdatedChangedInput();
    await translateDocument(after);
  }
};
