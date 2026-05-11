// SPDX-License-Identifier: MPL-2.0

import * as v from 'valibot'
import type { PermissionMode } from '../auth/authTypes'

export type BackendType = 'misskey' | 'mastodon' | 'bluesky'

export type Account = {
  id: string
  origin: string
  token: string
  username: string
  host: string
  avatarUrl: string
  permissionMode: PermissionMode
  backend: BackendType
  misskeyUserId: string
  mastodonAccountId: string
  blueskyDid: string
}

const AccountSchema = v.object({
  id: v.string(),
  origin: v.string(),
  token: v.string(),
  username: v.string(),
  host: v.string(),
  avatarUrl: v.fallback(v.string(), ''),
  permissionMode: v.fallback(v.picklist(['ReadOnly', 'Standard'] as const), 'Standard' as const),
  backend: v.fallback(v.picklist(['misskey', 'mastodon', 'bluesky'] as const), 'misskey' as const),
  misskeyUserId: v.fallback(v.string(), ''),
  mastodonAccountId: v.fallback(v.string(), ''),
  blueskyDid: v.fallback(v.string(), ''),
})

export function makeId(origin: string, username: string): string {
  return `${username}@${origin}`
}

export function displayLabel(account: Account): string {
  return `@${account.username}@${account.host}`
}

export function permissionModeToString(mode: PermissionMode): string {
  return mode
}

export function decodeAccount(json: unknown): Account | undefined {
  const result = v.safeParse(AccountSchema, json)
  return result.success ? result.output as Account : undefined
}

export function encodeAccount(account: Account): unknown {
  return { ...account }
}

export function serializeAccounts(accounts: Account[]): string {
  return JSON.stringify(accounts.map(encodeAccount))
}

export function deserializeAccounts(s: string): Account[] {
  try {
    const arr = JSON.parse(s)
    if (!Array.isArray(arr)) return []
    return arr.flatMap(item => {
      const a = decodeAccount(item)
      return a ? [a] : []
    })
  } catch {
    return []
  }
}
