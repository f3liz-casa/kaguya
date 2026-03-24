// SPDX-License-Identifier: MPL-2.0

open AppState
open AuthTypes

let finalizeLogin = (clientInstance: Misskey.t, accountId: string, origin: string) => {
  let _ = EmojiStore.prefetchDuringIdle(clientInstance)
  NetworkOptimizer.addPreconnectForInstance(Some(origin))
  NetworkOptimizer.prefetchCommonDomains(origin)
  NotificationStore.subscribe(clientInstance)
  let _ = PushNotificationStore.restore(clientInstance, accountId)
}

let login = async (~origin: string, ~token: string): result<unit, AuthTypes.loginError> => {
  let normalizedOrigin = UrlUtils.normalizeOrigin(origin)
  PreactSignals.setValue(authState, LoggingIn)
  let newClient = Misskey.connect(normalizedOrigin, ~token)

  try {
    let notifParams = Dict.make()
    notifParams->Dict.set("limit", JSON.Encode.int(30))

    let (userResult, notificationsResult, antennasResult, listsResult, channelsResult, homeTimelineResult) = await Promise.all6((
      newClient->Misskey.currentUser,
      newClient->Misskey.request("i/notifications", ~params=JSON.Encode.object(notifParams), ()),
      newClient->Misskey.CustomTimelines.antennas,
      newClient->Misskey.CustomTimelines.lists,
      newClient->Misskey.CustomTimelines.channels,
      newClient->Misskey.Notes.fetch(#home, ~limit=20, ()),
    ))

    switch userResult {
    | Ok(user) => {
        Storage.set(Storage.keyOrigin, normalizedOrigin)
        Storage.set(Storage.keyToken, token)

        let mode: option<AuthTypes.permissionMode> = switch Storage.get(Storage.keyPermissionMode) {
        | Some("ReadOnly") => Some(ReadOnly)
        | _ => Some(Standard)
        }

        let userObj = user->JSON.Decode.object
        let userUsername =
          userObj
          ->Option.flatMap(o => o->Dict.get("username"))
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("unknown")
        let userAvatarUrl =
          userObj
          ->Option.flatMap(o => o->Dict.get("avatarUrl"))
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("")
        let userHost = UrlUtils.hostnameFromOrigin(normalizedOrigin)
        let misskeyUserId =
          userObj
          ->Option.flatMap(o => o->Dict.get("id"))
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("")

        let accountId = Account.makeId(~origin=normalizedOrigin, ~username=userUsername)
        let account: Account.t = {
          id: accountId,
          origin: normalizedOrigin,
          token,
          username: userUsername,
          host: userHost,
          avatarUrl: userAvatarUrl,
          permissionMode: switch mode {
          | Some(ReadOnly) => AuthTypes.ReadOnly
          | _ => AuthTypes.Standard
          },
          misskeyUserId,
        }

        AccountManager.upsertAccount(account)
        Storage.set(Storage.keyActiveAccountId, accountId)

        NotificationStore.setInitial(notificationsResult)
        TimelineStore.setFromInitData(
          ~antennasResult,
          ~listsResult,
          ~channelsResult,
          ~homeTimelineResult=Some(homeTimelineResult),
        )

        PreactSignals.batch(() => {
          PreactSignals.setValue(instanceOrigin, Some(normalizedOrigin))
          PreactSignals.setValue(accessToken, Some(token))
          PreactSignals.setValue(client, Some(newClient))
          PreactSignals.setValue(currentUser, Some(user))
          PreactSignals.setValue(permissionMode, mode)
          PreactSignals.setValue(activeAccountId, Some(accountId))
          PreactSignals.setValue(authState, LoggedIn)
        })

        finalizeLogin(newClient, accountId, normalizedOrigin)
        Ok()
      }
    | Error(_) => {
        PreactSignals.setValue(authState, LoginFailed(InvalidCredentials))
        Error(InvalidCredentials)
      }
    }
  } catch {
  | _ => {
      let error = NetworkError("Network error during login")
      PreactSignals.setValue(authState, LoginFailed(error))
      Error(error)
    }
  }
}

let teardownStores = () => {
  NotificationStore.unsubscribe()
  NotificationStore.clear()
  TimelineStore.clear()
  EmojiStore.clear()
}

let logout = (): unit => {
  let currentId = PreactSignals.value(activeAccountId)

  currentId->Option.forEach(id => AccountManager.removeAccount(id))

  Storage.remove(Storage.keyOrigin)
  Storage.remove(Storage.keyToken)
  Storage.remove(Storage.keyPermissionMode)
  Storage.remove(Storage.keyActiveAccountId)
  Storage.remove(Storage.keyMiAuthSession)
  Storage.remove(Storage.keyMiAuthOrigin)

  switch PreactSignals.value(client) {
  | Some(c) => {
      c->Misskey.close
      currentId->Option.forEach(id => {
        let _ = PushNotificationStore.unsubscribe(c, id)
      })
    }
  | None => ()
  }

  teardownStores()

  PreactSignals.batch(() => {
    PreactSignals.setValue(instanceOrigin, None)
    PreactSignals.setValue(accessToken, None)
    PreactSignals.setValue(client, None)
    PreactSignals.setValue(currentUser, None)
    PreactSignals.setValue(permissionMode, None)
    PreactSignals.setValue(activeAccountId, None)
    PreactSignals.setValue(authState, LoggedOut)
  })
}

let switchAccount = async (accountId: string): result<unit, AuthTypes.loginError> => {
  let accs = PreactSignals.value(accounts)
  switch accs->Array.find(a => a.id == accountId) {
  | Some(account) => {
      PreactSignals.setValue(isSwitchingAccount, true)

      switch PreactSignals.value(client) {
      | Some(c) => c->Misskey.close
      | None => ()
      }
      teardownStores()

      Storage.set(Storage.keyActiveAccountId, accountId)
      Storage.set(
        Storage.keyPermissionMode,
        Account.permissionModeToString(account.permissionMode),
      )

      let result = await login(~origin=account.origin, ~token=account.token)
      PreactSignals.setValue(isSwitchingAccount, false)
      result
    }
  | None => Error(UnknownError("Account not found"))
  }
}

let restoreSession = async (): unit => {
  let storedAccounts = PreactSignals.value(accounts)

  if Array.length(storedAccounts) > 0 {
    switch AccountManager.getActiveAccount() {
    | Some(account) => {
        let _ = await login(~origin=account.origin, ~token=account.token)
      }
    | None => ()
    }
  } else {
    switch (Storage.get(Storage.keyOrigin), Storage.get(Storage.keyToken)) {
    | (Some(origin), Some(token)) => {
        let _ = await login(~origin, ~token)
      }
    | _ => ()
    }
  }
}
