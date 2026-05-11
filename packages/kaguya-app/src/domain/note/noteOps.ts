// SPDX-License-Identifier: MPL-2.0

import type { NoteView } from './noteView'
import { isImage, displayUrl } from '../file/fileView'
import { proxyUrl, proxyAvatarUrl } from '../../infra/mediaProxy'
import { enqueue, enqueueMany } from '../../infra/fetchQueue'

/**
 * Fire-and-forget prefetch for all images in a note.
 *
 * Priority assignments:
 *   P2 — avatar (user profile image)
 *   P4 — file attachments (note images)
 *   P5 — reaction emoji
 */
export function prefetchNoteImages(note: NoteView): void {
  if (note.user.avatarUrl) {
    void enqueue(proxyAvatarUrl(note.user.avatarUrl), 2)
  }

  const fileUrls = note.files.filter(isImage).map(f => proxyUrl(displayUrl(f)))
  if (fileUrls.length > 0) enqueueMany(fileUrls, 4)

  const emojiUrls = Object.values(note.reactionEmojis).filter(url => url !== '').map(proxyUrl)
  if (emojiUrls.length > 0) enqueueMany(emojiUrls, 5)

  if (note.renote) prefetchNoteImages(note.renote)
}
