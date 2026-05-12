// SPDX-License-Identifier: MPL-2.0

import { signal } from '@preact/signals-core'
import { isPureRenote, hasMedia } from '../note/noteView'
import type { NoteView } from '../note/noteView'

const KEY = 'kaguya:userFilters'

export type UserFilter = {
  userId: string
  imagesOnly: boolean
  noRenotes: boolean
}

function load(): UserFilter[] {
  if (typeof localStorage === 'undefined') return []
  try {
    const raw = localStorage.getItem(KEY)
    if (!raw) return []
    const parsed = JSON.parse(raw) as unknown
    if (!Array.isArray(parsed)) return []
    return parsed.filter((f): f is UserFilter =>
      typeof f === 'object' && f !== null &&
      typeof (f as UserFilter).userId === 'string' &&
      typeof (f as UserFilter).imagesOnly === 'boolean' &&
      typeof (f as UserFilter).noRenotes === 'boolean'
    )
  } catch {
    return []
  }
}

function save(filters: UserFilter[]): void {
  if (typeof localStorage === 'undefined') return
  localStorage.setItem(KEY, JSON.stringify(filters))
}

export const userFilters = signal<UserFilter[]>(load())

export function setUserFilter(filter: UserFilter): void {
  const existing = userFilters.value.filter(f => f.userId !== filter.userId)
  const isActive = filter.imagesOnly || filter.noRenotes
  const next = isActive ? [...existing, filter] : existing
  userFilters.value = next
  save(next)
}

export function getUserFilter(userId: string): UserFilter | undefined {
  return userFilters.value.find(f => f.userId === userId)
}

export function shouldShowNote(note: NoteView): boolean {
  const filter = userFilters.value.find(f => f.userId === note.user.id)
  if (!filter) return true
  if (filter.noRenotes && isPureRenote(note)) return false
  if (filter.imagesOnly) {
    // A pure renote carries no top-level files, so hasMedia(note) is false —
    // but the renoted note can still be an image post. Allow those through.
    const hasOwnMedia = hasMedia(note)
    const renotedMedia = note.renote !== undefined && hasMedia(note.renote)
    if (!hasOwnMedia && !renotedMedia) return false
  }
  return true
}
