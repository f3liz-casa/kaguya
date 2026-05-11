// SPDX-License-Identifier: MPL-2.0

import { batch } from '@preact/signals'
import { accounts, activeAccountId } from '../auth/appState'
import type { Account } from './account'
import { serializeAccounts } from './account'
import * as storage from '../../infra/storage'

function persist(accs: Account[]): void {
  storage.set(storage.keyAccounts, serializeAccounts(accs))
}

export function getActiveAccount(): Account | undefined {
  const id = activeAccountId.value
  const accs = accounts.value
  if (id) return accs.find(a => a.id === id)
  return accs[0]
}

export function upsertAccount(account: Account): void {
  const current = accounts.value
  const idx = current.findIndex(a => a.id === account.id)
  const updated = idx === -1
    ? [...current, account]
    : current.map((a, i) => i === idx ? account : a)
  persist(updated)
  accounts.value = updated
}

export function removeAccount(accountId: string): void {
  const remaining = accounts.value.filter(a => a.id !== accountId)
  persist(remaining)
  accounts.value = remaining
}
