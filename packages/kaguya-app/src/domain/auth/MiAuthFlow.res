// SPDX-License-Identifier: MPL-2.0

let getPermissionsForMode = (mode: AuthTypes.permissionMode): array<Misskey.MiAuth.permission> => {
  switch mode {
  | ReadOnly => [
      #read_account,
      #read_blocks,
      #read_drive,
      #read_favorites,
      #read_following,
      #read_notifications,
      #read_reactions,
      #read_pages,
      #read_page_likes,
      #read_channels,
      #read_gallery,
      #read_gallery_likes,
      #read_flash,
      #read_flash_likes,
    ]
  | Standard => [
      #read_account,
      #write_account,
      #read_blocks,
      #write_blocks,
      #read_drive,
      #write_drive,
      #read_favorites,
      #write_favorites,
      #read_following,
      #write_following,
      #read_notifications,
      #write_notifications,
      #read_reactions,
      #write_reactions,
      #write_notes,
      #write_votes,
      #read_pages,
      #read_channels,
      #write_channels,
      #read_gallery,
      #read_flash,
    ]
  }
}

let startMiAuth = (~origin: string, ~mode: AuthTypes.permissionMode=Standard, ()): unit => {
  let normalizedOrigin = UrlUtils.normalizeOrigin(origin)
  let permissions = getPermissionsForMode(mode)

  let session = Misskey.MiAuth.generateUrl(
    ~origin=normalizedOrigin,
    ~name="Kaguya",
    ~permissions,
    ~callback=`${KaguyaNetwork.locationOrigin()}/miauth-callback`,
    (),
  )

  Storage.set(Storage.keyMiAuthSession, session.sessionId)
  Storage.set(Storage.keyMiAuthOrigin, normalizedOrigin)
  Storage.set(Storage.keyPermissionMode, mode == ReadOnly ? "ReadOnly" : "Standard")

  Misskey.MiAuth.openUrl(session.authUrl)
}

let checkMiAuth = async (): result<unit, AuthTypes.loginError> => {
  let sessionOpt = Storage.get(Storage.keyMiAuthSession)
  let originOpt = Storage.get(Storage.keyMiAuthOrigin)

  switch (sessionOpt, originOpt) {
  | (Some(sessionId), Some(origin)) => {
      PreactSignals.setValue(AppState.authState, LoggingIn)
      let checkResult = await Misskey.MiAuth.check(~origin, ~sessionId)

      switch checkResult {
      | Ok({token: Some(token), user: _}) => {
          Storage.remove(Storage.keyMiAuthSession)
          Storage.remove(Storage.keyMiAuthOrigin)
          await AuthService.login(~origin, ~token)
        }
      | Ok({token: None, user: _}) =>
        Error(UnknownError("Authorization pending."))
      | Error(_) => {
          PreactSignals.setValue(AppState.authState, LoginFailed(InvalidCredentials))
          Error(InvalidCredentials)
        }
      }
    }
  | _ => Error(UnknownError("Session not found"))
  }
}
