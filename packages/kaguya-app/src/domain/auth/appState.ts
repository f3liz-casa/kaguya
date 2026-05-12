// SPDX-License-Identifier: MPL-2.0

import { signal, computed } from '@preact/signals-core'
import type { AuthState, PermissionMode } from './authTypes'
import type { Account } from '../account/account'
import type { BackendClient } from '../../lib/backend'
import * as storage from '../../infra/storage'
import { hostnameFromOrigin } from '../../infra/urlUtils'
import { deserializeAccounts } from '../account/account'
import { asObj, getString } from '../../infra/jsonUtils'

function initialAuthState(): AuthState {
  const hasAccounts = (storage.get(storage.keyAccounts)?.trim().length ?? 0) > 2
  const hasLegacy = storage.get(storage.keyOrigin) && storage.get(storage.keyToken)
  return hasAccounts || hasLegacy ? 'LoggingIn' : 'LoggedOut'
}

function initialPermissionMode(): PermissionMode | undefined {
  const v = storage.get(storage.keyPermissionMode)
  if (v === 'ReadOnly') return 'ReadOnly'
  if (v === 'Standard') return 'Standard'
  return undefined
}

export const instanceOrigin = signal<string | undefined>(storage.get(storage.keyOrigin))
export const accessToken = signal<string | undefined>(storage.get(storage.keyToken))
export const authState = signal<AuthState>(initialAuthState())
export const isSwitchingAccount = signal(false)
export const client = signal<BackendClient | undefined>(undefined)
export const currentUser = signal<unknown>(undefined)
export const permissionMode = signal<PermissionMode | undefined>(initialPermissionMode())
export const accounts = signal<Account[]>(
  storage.get(storage.keyAccounts) ? deserializeAccounts(storage.get(storage.keyAccounts)!) : []
)
export const activeAccountId = signal<string | undefined>(storage.get(storage.keyActiveAccountId))

export const isLoggedIn = computed(() => authState.value === 'LoggedIn')

export const instanceName = computed(() =>
  instanceOrigin.value ? hostnameFromOrigin(instanceOrigin.value) : ''
)

export function isReadOnlyMode(): boolean {
  return permissionMode.value === 'ReadOnly'
}

export function getCurrentUserName(): string | undefined {
  const user = currentUser.value
  const obj = asObj(user)
  if (!obj) return undefined
  return getString(obj, 'name') || getString(obj, 'username')
}
