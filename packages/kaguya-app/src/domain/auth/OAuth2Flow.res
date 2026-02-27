// SPDX-License-Identifier: MPL-2.0

let getScopeForMode = (mode: AuthTypes.permissionMode): string => {
  MiAuthFlow.getPermissionsForMode(mode)
  ->Array.map(Misskey.MiAuth.permissionToString)
  ->Array.join(" ")
}

let makeProxiedFetch = (): OpenIDClient.customFetchFn => {
  let proxyBase = KaguyaNetwork.locationOrigin() ++ "/api/oauth-proxy/"
  KaguyaNetwork.makeProxiedFetch(proxyBase)->Obj.magic
}

let startOAuth2 = async (~origin: string, ~mode: AuthTypes.permissionMode=Standard, ()): result<unit, AuthTypes.loginError> => {
  let normalizedOrigin = UrlUtils.normalizeOrigin(origin)
  try {
    let clientId = KaguyaNetwork.locationOrigin() ++ "/"
    let proxyFetch = makeProxiedFetch()
    let discoveryOptions = OpenIDClient.makeDiscoveryOptions(proxyFetch)
    let serverUrl = URL.make(normalizedOrigin)

    let config = await OpenIDClient.discovery(
      serverUrl,
      clientId,
      Nullable.null,
      OpenIDClient.clientAuthNone(),
      discoveryOptions,
    )

    let codeVerifier = OpenIDClient.randomPKCECodeVerifier()
    let codeChallenge = await OpenIDClient.calculatePKCECodeChallenge(codeVerifier)
    let state = OpenIDClient.randomState()
    let scope = getScopeForMode(mode)

    Storage.set(Storage.keyOAuth2CodeVerifier, codeVerifier)
    Storage.set(Storage.keyOAuth2State, state)
    Storage.set(Storage.keyOAuth2Origin, normalizedOrigin)
    Storage.set(Storage.keyOAuth2Scope, scope)
    Storage.set(Storage.keyPermissionMode, mode == ReadOnly ? "ReadOnly" : "Standard")

    let redirectUri = `${KaguyaNetwork.locationOrigin()}/oauth-callback`
    let params = Dict.make()
    params->Dict.set("redirect_uri", redirectUri)
    params->Dict.set("scope", scope)
    params->Dict.set("code_challenge", codeChallenge)
    params->Dict.set("code_challenge_method", "S256")
    params->Dict.set("state", state)
    params->Dict.set("response_type", "code")

    let authUrl = OpenIDClient.buildAuthorizationUrl(config, params)
    Misskey.MiAuth.openUrl(URL.href(authUrl))
    Ok()
  } catch {
  | exn =>
    let msg =
      exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("OAuth2 failed")
    Error(NetworkError(msg))
  }
}

let checkOAuth2 = async (): result<unit, AuthTypes.loginError> => {
  let codeVerifierOpt = Storage.get(Storage.keyOAuth2CodeVerifier)
  let stateOpt = Storage.get(Storage.keyOAuth2State)
  let originOpt = Storage.get(Storage.keyOAuth2Origin)

  switch (codeVerifierOpt, stateOpt, originOpt) {
  | (Some(codeVerifier), Some(expectedState), Some(origin)) => {
      let scopeOpt = Storage.get(Storage.keyOAuth2Scope)
      Storage.remove(Storage.keyOAuth2CodeVerifier)
      Storage.remove(Storage.keyOAuth2State)
      Storage.remove(Storage.keyOAuth2Origin)
      Storage.remove(Storage.keyOAuth2Scope)

      PreactSignals.setValue(AppState.authState, LoggingIn)

      try {
        let clientId = KaguyaNetwork.locationOrigin() ++ "/"
        let serverUrl = URL.make(origin)
        let proxyFetch = makeProxiedFetch()
        let discoveryOptions = OpenIDClient.makeDiscoveryOptions(proxyFetch)

        let config = await OpenIDClient.discovery(
          serverUrl,
          clientId,
          Nullable.null,
          OpenIDClient.clientAuthNone(),
          discoveryOptions,
        )

        let currentUrl = URL.make(KaguyaNetwork.locationHref())
        let tokenParams = Dict.make()
        scopeOpt->Option.forEach(s => tokenParams->Dict.set("scope", s))

        let tokens = await OpenIDClient.authorizationCodeGrant(
          config,
          currentUrl,
          {"pkceCodeVerifier": codeVerifier, "expectedState": expectedState},
          tokenParams,
        )

        KaguyaNetwork.replaceState("/")
        await AuthService.login(~origin, ~token=tokens.access_token)
      } catch {
      | exn =>
        let msg =
          exn
          ->JsExn.fromException
          ->Option.flatMap(JsExn.message)
          ->Option.getOr("Token exchange failed")
        PreactSignals.setValue(AppState.authState, LoginFailed(NetworkError(msg)))
        Error(NetworkError(msg))
      }
    }
  | _ => Error(UnknownError("OAuth2 session data not found"))
  }
}
