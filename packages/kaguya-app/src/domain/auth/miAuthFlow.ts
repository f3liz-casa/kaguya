// SPDX-License-Identifier: MPL-2.0

import type { PermissionMode, LoginError } from './authTypes'
import type { MisskeyPermission } from '../../lib/misskey'
import { MiAuth } from '../../lib/misskey'
import type { Result } from '../../infra/result'
import { err } from '../../infra/result'
import { normalizeOrigin } from '../../infra/urlUtils'
import * as storage from '../../infra/storage'
import { authState } from './appState'
import { login } from './authService'

export function getPermissionsForMode(mode: PermissionMode): MisskeyPermission[] {
  if (mode === 'ReadOnly') {
    return [
      'read_account',
      'read_blocks',
      'read_drive',
      'read_favorites',
      'read_following',
      'read_notifications',
      'read_reactions',
      'read_pages',
      'read_page_likes',
      'read_channels',
      'read_gallery',
      'read_gallery_likes',
      'read_flash',
      'read_flash_likes',
    ]
  }
  return [
    'read_account',
    'write_account',
    'read_blocks',
    'write_blocks',
    'read_drive',
    'write_drive',
    'read_favorites',
    'write_favorites',
    'read_following',
    'write_following',
    'read_notifications',
    'write_notifications',
    'read_reactions',
    'write_reactions',
    'write_notes',
    'write_votes',
    'read_pages',
    'read_channels',
    'write_channels',
    'read_gallery',
    'read_flash',
  ]
}

export function startMiAuth(opts: { origin: string; mode?: PermissionMode }): void {
  const mode = opts.mode ?? 'Standard'
  const normalized = normalizeOrigin(opts.origin)
  const permissions = getPermissionsForMode(mode)
  const callback = `${window.location.origin}/miauth-callback`

  const session = MiAuth.generateUrl(normalized, 'Kaguya', permissions, callback)

  storage.set(storage.keyMiAuthSession, session.sessionId)
  storage.set(storage.keyMiAuthOrigin, normalized)
  storage.set(storage.keyPermissionMode, mode === 'ReadOnly' ? 'ReadOnly' : 'Standard')

  MiAuth.openUrl(session.authUrl)
}

export async function checkMiAuth(): Promise<Result<void, LoginError>> {
  const sessionId = storage.get(storage.keyMiAuthSession)
  const origin = storage.get(storage.keyMiAuthOrigin)

  if (!sessionId || !origin) {
    return err({ type: 'SessionExpired' })
  }

  authState.value = 'LoggingIn'
  const checkResult = await MiAuth.check(origin, sessionId)

  if (!checkResult.ok) {
    authState.value = { type: 'LoginFailed', error: { type: 'InvalidCredentials' } }
    return err({ type: 'InvalidCredentials' })
  }

  const token = checkResult.value.token
  if (!token) {
    return err({ type: 'UnknownError', message: 'Authorization pending.' })
  }

  storage.remove(storage.keyMiAuthSession)
  storage.remove(storage.keyMiAuthOrigin)
  return login({ origin, token })
}
