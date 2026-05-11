// SPDX-License-Identifier: MPL-2.0

import { asObj, getString } from '../../infra/jsonUtils'
import { fixAvatarUrl } from '../../infra/urlUtils'

export type UserView = {
  id: string
  name: string
  username: string
  avatarUrl: string
  host: string | undefined
}

export function fullUsername(user: UserView): string {
  return user.host ? `@${user.username}@${user.host}` : `@${user.username}`
}

export function displayName(user: UserView): string {
  return user.name || user.username
}

export function decode(json: unknown): UserView | undefined {
  const obj = asObj(json)
  if (!obj) return undefined
  const id = getString(obj, 'id')
  const username = getString(obj, 'username')
  if (!id || !username) return undefined

  const nameRaw = getString(obj, 'name')
  const name = nameRaw ?? username
  const avatarUrl = fixAvatarUrl(getString(obj, 'avatarUrl') ?? '')
  const hostRaw = obj['host']
  const host = hostRaw === null || hostRaw === undefined ? undefined : String(hostRaw)

  return { id, name, username, avatarUrl, host }
}
