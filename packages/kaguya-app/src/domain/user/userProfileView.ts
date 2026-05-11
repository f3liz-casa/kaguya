// SPDX-License-Identifier: MPL-2.0

import { asObj, getString, getBool, getFloat, getArray, getObj } from '../../infra/jsonUtils'
import { fixAvatarUrl } from '../../infra/urlUtils'

export type Field = { fieldName: string; fieldValue: string }

export type UserProfileView = {
  id: string
  name: string
  username: string
  avatarUrl: string
  host: string | undefined
  description: string | undefined
  bannerUrl: string | undefined
  notesCount: number
  followingCount: number
  followersCount: number
  pinnedNoteIds: string[]
  isBot: boolean
  createdAt: string
  fields: Field[]
  isFollowing: boolean
}

export function fullUsername(user: UserProfileView): string {
  return user.host ? `@${user.username}@${user.host}` : `@${user.username}`
}

export function displayName(user: UserProfileView): string {
  return user.name || user.username
}

export function decode(json: unknown): UserProfileView | undefined {
  const obj = asObj(json)
  if (!obj) return undefined

  const id = getString(obj, 'id')
  const username = getString(obj, 'username')
  if (!id || !username) return undefined

  const pinnedNoteIds = (getArray(obj, 'pinnedNoteIds') ?? [])
    .flatMap(v => typeof v === 'string' ? [v] : [])

  const fields: Field[] = (getArray(obj, 'fields') ?? [])
    .flatMap(item => {
      const f = asObj(item)
      if (!f) return []
      const fieldName = getString(f, 'name')
      const fieldValue = getString(f, 'value')
      return fieldName && fieldValue ? [{ fieldName, fieldValue }] : []
    })

  const avatarUrl = fixAvatarUrl(getString(obj, 'avatarUrl') ?? '')
  const hostRaw = obj['host']
  const host = hostRaw === null || hostRaw === undefined ? undefined : String(hostRaw)

  return {
    id,
    name: getString(obj, 'name') ?? username,
    username,
    avatarUrl,
    host,
    description: getString(obj, 'description'),
    bannerUrl: getString(obj, 'bannerUrl'),
    notesCount: Math.floor(getFloat(obj, 'notesCount') ?? 0),
    followingCount: Math.floor(getFloat(obj, 'followingCount') ?? 0),
    followersCount: Math.floor(getFloat(obj, 'followersCount') ?? 0),
    pinnedNoteIds,
    isBot: getBool(obj, 'isBot') ?? false,
    createdAt: getString(obj, 'createdAt') ?? '',
    fields,
    isFollowing: getBool(obj, 'isFollowing') ?? false,
  }
}
