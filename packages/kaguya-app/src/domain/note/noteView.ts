// SPDX-License-Identifier: MPL-2.0

import type { UserView } from '../user/userView'
import type { FileView } from '../file/fileView'
import type { BlueskyFacet } from '../../ui/content/fromFacets'
import type { ReactionAcceptance } from '../../infra/sharedTypes'
import { isImage } from '../file/fileView'
import { formatRelativeTime } from '../../infra/timeFormat'

export type PollChoice = {
  text: string
  votes: number
  isVoted: boolean
}

export type PollView = {
  choices: PollChoice[]
  multiple: boolean
  expiresAt: string | undefined
}

export type ContentType = 'mfm' | 'html' | 'bluesky'

export type NoteView = {
  id: string
  user: UserView
  text: string | undefined
  contentType?: ContentType
  facets?: BlueskyFacet[]
  cw: string | undefined
  createdAt: string
  files: FileView[]
  reactions: Record<string, number>
  reactionEmojis: Record<string, string>
  myReaction: string | undefined
  reactionAcceptance: ReactionAcceptance | undefined
  renote: NoteView | undefined
  replyId: string | undefined
  reply: NoteView | undefined
  uri: string | undefined
  poll: PollView | undefined
  /** Bluesky CID for like/repost operations */
  _bskyCid?: string
}

export function relativeTime(note: NoteView): string {
  return formatRelativeTime(note.createdAt)
}

export function isPureRenote(note: NoteView): boolean {
  return note.text === undefined && note.files.length === 0 && note.renote !== undefined
}

export function hasContentWarning(note: NoteView): boolean {
  return note.cw !== undefined
}

export function isNsfw(note: NoteView): boolean {
  if (note.cw !== undefined) return true
  if (note.files.some(f => f.isSensitive)) return true
  if (note.renote !== undefined && isNsfw(note.renote)) return true
  return false
}

export function hasMedia(note: NoteView): boolean {
  return note.files.length > 0
}

export function imageFiles(note: NoteView): FileView[] {
  return note.files.filter(isImage)
}

export function reactionCount(note: NoteView): number {
  return Object.values(note.reactions).reduce((acc, count) => acc + count, 0)
}

export function hasUserReacted(note: NoteView): boolean {
  return note.myReaction !== undefined
}
