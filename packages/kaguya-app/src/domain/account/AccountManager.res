// SPDX-License-Identifier: MPL-2.0

open AppState

// Persist accounts array to localStorage
let persistAccounts = (accs: array<Account.t>): unit => {
  Storage.set(Storage.keyAccounts, Account.serialize(accs))
}

let getActiveAccount = (): option<Account.t> => {
  let id = PreactSignals.value(activeAccountId)
  let accs = PreactSignals.value(accounts)
  switch id {
  | Some(activeId) => accs->Array.find(a => a.id == activeId)
  | None => accs->Array.get(0)
  }
}

let upsertAccount = (account: Account.t): unit => {
  let currentAccounts = PreactSignals.value(accounts)
  let updatedAccounts = switch currentAccounts->Array.findIndex(a => a.id == account.id) {
  | -1 => Array.concat(currentAccounts, [account])
  | idx => currentAccounts->Array.mapWithIndex((a, i) => i == idx ? account : a)
  }
  
  persistAccounts(updatedAccounts)
  PreactSignals.setValue(accounts, updatedAccounts)
}

let removeAccount = (accountId: string): unit => {
  let currentAccounts = PreactSignals.value(accounts)
  let remaining = currentAccounts->Array.filter(a => a.id != accountId)
  persistAccounts(remaining)
  PreactSignals.setValue(accounts, remaining)
}
