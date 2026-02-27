// SPDX-License-Identifier: MPL-2.0

let instanceOrigin: PreactSignals.signal<option<string>> = PreactSignals.make(
  Storage.get(Storage.keyOrigin),
)

let accessToken: PreactSignals.signal<option<string>> = PreactSignals.make(
  Storage.get(Storage.keyToken),
)

let authState: PreactSignals.signal<AuthTypes.authState> = PreactSignals.make(
  if (
    Storage.get(Storage.keyAccounts)
    ->Option.map(s => String.length(String.trim(s)) > 2)
    ->Option.getOr(false)
  ) || (
    Storage.get(Storage.keyOrigin)->Option.isSome &&
    Storage.get(Storage.keyToken)->Option.isSome
  ) {
    (LoggingIn: AuthTypes.authState)
  } else {
    (LoggedOut: AuthTypes.authState)
  },
)

let isSwitchingAccount: PreactSignals.signal<bool> = PreactSignals.make(false)
let client: PreactSignals.signal<option<Misskey.t>> = PreactSignals.make(None)
let currentUser: PreactSignals.signal<option<JSON.t>> = PreactSignals.make(None)

let permissionMode: PreactSignals.signal<option<AuthTypes.permissionMode>> = PreactSignals.make(
  switch Storage.get(Storage.keyPermissionMode) {
  | Some("ReadOnly") => Some(AuthTypes.ReadOnly)
  | Some("Standard") => Some(AuthTypes.Standard)
  | _ => None
  },
)

let accounts: PreactSignals.signal<array<Account.t>> = PreactSignals.make(
  Storage.get(Storage.keyAccounts)
  ->Option.map(Account.deserialize)
  ->Option.getOr([]),
)

let activeAccountId: PreactSignals.signal<option<string>> = PreactSignals.make(
  Storage.get(Storage.keyActiveAccountId),
)

let isLoggedIn: PreactSignals.computed<bool> = PreactSignals.computed(() => {
  PreactSignals.value(authState) == LoggedIn
})

let instanceName: PreactSignals.computed<string> = PreactSignals.computed(() => {
  PreactSignals.value(instanceOrigin)
  ->Option.map(UrlUtils.hostnameFromOrigin)
  ->Option.getOr("")
})

let isReadOnlyMode = (): bool => {
  PreactSignals.value(permissionMode) == Some(AuthTypes.ReadOnly)
}

let getCurrentUserName = (): option<string> => {
  PreactSignals.value(currentUser)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.flatMap(obj =>
    obj
    ->Dict.get("name")
    ->Option.flatMap(JSON.Decode.string)
    ->Option.orElse(obj->Dict.get("username")->Option.flatMap(JSON.Decode.string))
  )
}
