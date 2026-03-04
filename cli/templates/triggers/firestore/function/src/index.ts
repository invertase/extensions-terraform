/**
 * Copyright {{YEAR}} Google LLC
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

import { onDocumentWritten } from "firebase-functions/v2/firestore";

export const {{FUNCTION_NAME}} = onDocumentWritten(
  `${process.env.COLLECTION_PATH}/{docId}`,
  async (event) => {
    const { before, after } = event.data ?? {};

    if (!after?.exists) {
      // Document deleted — clean up if needed.
      return;
    }

    const isCreate = !before?.exists;
    const data = after.data();
    if (!data) return;

    if (isCreate) {
      // TODO: handle document create
    } else {
      // TODO: handle document update
    }
  }
);
