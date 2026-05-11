// SPDX-License-Identifier: MPL-2.0
//
// Early note prefetch — starts fetching note data as soon as JS loads,
// in parallel with auth restoration. Reads credentials directly from
// localStorage to avoid waiting for the auth flow.

const CACHE_NAME = 'kaguya-note-prefetch'

type PrefetchEntry = {
  noteId: string
  promise: Promise<unknown | null>
}

let pending: PrefetchEntry | undefined

function parseNoteUrl(): { noteId: string; userId?: string; host?: string } | null {
  const path = location.pathname
  // /push/notes/:noteId
  const pushMatch = path.match(/^\/push\/notes\/([a-zA-Z0-9]+)/)
  if (pushMatch) {
    const params = new URLSearchParams(location.search)
    return { noteId: pushMatch[1], userId: params.get('userId') ?? undefined }
  }
  // /notes/:noteId/:host
  const noteMatch = path.match(/^\/notes\/([a-zA-Z0-9]+)\/(.+)/)
  if (noteMatch) {
    return { noteId: noteMatch[1], host: noteMatch[2] }
  }
  return null
}

function getCredentials(userId?: string): { origin: string; token: string } | null {
  const accountsJson = localStorage.getItem('kaguya:accounts')
  if (accountsJson) {
    try {
      const accounts = JSON.parse(accountsJson)
      if (Array.isArray(accounts)) {
        // Match by userId if provided, otherwise use active account
        const activeId = localStorage.getItem('kaguya:activeAccountId')
        const account = userId
          ? accounts.find((a: any) => a.misskeyUserId === userId) ?? accounts.find((a: any) => a.id === activeId)
          : accounts.find((a: any) => a.id === activeId)
        if (account?.origin && account?.token) {
          return { origin: account.origin, token: account.token }
        }
      }
    } catch { /* ignore */ }
  }
  // Legacy single-account fallback
  const origin = localStorage.getItem('kaguya:instanceOrigin')
  const token = localStorage.getItem('kaguya:accessToken')
  if (origin && token) return { origin, token }
  return null
}

async function fetchNote(origin: string, token: string, noteId: string): Promise<unknown | null> {
  try {
    const res = await fetch(`${origin}/api/notes/show`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ i: token, noteId }),
    })
    if (!res.ok) return null
    return await res.json()
  } catch {
    return null
  }
}

// Start prefetch immediately on module load
function initPrefetch(): void {
  const parsed = parseNoteUrl()
  if (!parsed) return
  const creds = getCredentials(parsed.userId)
  if (!creds) return

  // For push routes, the note is always local to the matched account's instance
  // For direct note routes, host is known
  pending = {
    noteId: parsed.noteId,
    promise: fetchNote(creds.origin, creds.token, parsed.noteId),
  }
}

/**
 * Consume a prefetched note result. Returns the JSON if the prefetch
 * was for this noteId and succeeded, otherwise null.
 * Can only be consumed once.
 */
export async function consumePrefetch(noteId: string): Promise<unknown | null> {
  if (!pending || pending.noteId !== noteId) return null
  const entry = pending
  pending = undefined
  return entry.promise
}

/**
 * Check the SW note preview cache for partial note data
 * cached when the push notification was received.
 */
export async function consumeSwPreview(noteId: string): Promise<{ text: string; userName: string; userUsername: string; avatarUrl: string } | null> {
  try {
    const cache = await caches.open(CACHE_NAME)
    const key = `${location.origin}/_note-preview/${noteId}`
    const res = await cache.match(key)
    if (!res) return null
    await cache.delete(key)
    return await res.json()
  } catch {
    return null
  }
}

// Fire immediately
initPrefetch()
