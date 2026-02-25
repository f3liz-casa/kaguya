// SPDX-License-Identifier: MPL-2.0
// AppState.res - Global application state using Preact Signals

// ============================================================
// Types
// ============================================================

type loginError =
  | InvalidCredentials
  | NetworkError(string)
  | UnknownError(string)

type authState =
  | LoggedOut
  | LoggingIn
  | LoggedIn
  | LoginFailed(loginError)

// Permission mode for MiAuth
type permissionMode = ReadOnly | Standard

// ============================================================
// LocalStorage Keys
// ============================================================

// Legacy single-account keys (kept for migration)
let storageKeyOrigin = "kaguya:instanceOrigin"
let storageKeyToken = "kaguya:accessToken"
let storageKeyMiAuthSession = "kaguya:miAuthSession"
let storageKeyMiAuthOrigin = "kaguya:miAuthOrigin"
let storageKeyPermissionMode = "kaguya:permissionMode"

// Multi-account storage keys
let storageKeyAccounts = "kaguya:accounts"
let storageKeyActiveAccountId = "kaguya:activeAccountId"

// OAuth2 storage keys
let storageKeyOAuth2CodeVerifier = "kaguya:oauth2:codeVerifier"
let storageKeyOAuth2State = "kaguya:oauth2:state"
let storageKeyOAuth2Origin = "kaguya:oauth2:origin"
let storageKeyOAuth2Scope = "kaguya:oauth2:scope"

// ============================================================
// LocalStorage Bindings
// ============================================================

@val @scope("localStorage")
external getItem: string => Nullable.t<string> = "getItem"

@val @scope("localStorage")
external setItem: (string, string) => unit = "setItem"

@val @scope("localStorage")
external removeItem: string => unit = "removeItem"

// ============================================================
// LocalStorage Helpers
// ============================================================

let getStoredValue = (key: string): option<string> => {
  getItem(key)->Nullable.toOption
}

let setStoredValue = (key: string, value: string): unit => {
  setItem(key, value)
}

let removeStoredValue = (key: string): unit => {
  removeItem(key)
}

// ============================================================
// Global Signals
// ============================================================

// Instance origin (e.g., "https://misskey.io")
let instanceOrigin: PreactSignals.signal<option<string>> = PreactSignals.make(
  getStoredValue(storageKeyOrigin),
)

// Access token
let accessToken: PreactSignals.signal<option<string>> = PreactSignals.make(
  getStoredValue(storageKeyToken),
)

// Authentication state — start as LoggingIn if stored credentials exist,
// to avoid showing the login page briefly on refresh when already logged in.
let authState: PreactSignals.signal<authState> = PreactSignals.make(
  if (
    // Multi-account: non-empty accounts array in localStorage
    getStoredValue(storageKeyAccounts)
    ->Option.map(s => String.length(String.trim(s)) > 2)
    ->Option.getOr(false)
  ) || (
    // Legacy single-account: origin + token stored
    getStoredValue(storageKeyOrigin)->Option.isSome &&
    getStoredValue(storageKeyToken)->Option.isSome
  ) {
    LoggingIn
  } else {
    LoggedOut
  },
)

// Set to true while switching accounts so the UI can show the previous session
// content (rather than a blank loading screen) while the new session loads.
let isSwitchingAccount: PreactSignals.signal<bool> = PreactSignals.make(false)

// Misskey Client
let client: PreactSignals.signal<option<Misskey.t>> = PreactSignals.make(None)

// Current user info
let currentUser: PreactSignals.signal<option<JSON.t>> = PreactSignals.make(None)

// Permission mode (ReadOnly or Standard)
let permissionMode: PreactSignals.signal<option<permissionMode>> = PreactSignals.make(
  switch getStoredValue(storageKeyPermissionMode) {
  | Some("ReadOnly") => Some(ReadOnly)
  | Some("Standard") => Some(Standard)
  | _ => None
  },
)

// Multi-account signals
let accounts: PreactSignals.signal<array<Account.t>> = PreactSignals.make(
  getStoredValue(storageKeyAccounts)
  ->Option.map(Account.deserialize)
  ->Option.getOr([]),
)

let activeAccountId: PreactSignals.signal<option<string>> = PreactSignals.make(
  getStoredValue(storageKeyActiveAccountId),
)

// ============================================================
// Computed Signals
// ============================================================

let isLoggedIn: PreactSignals.computed<bool> = PreactSignals.computed(() => {
  switch PreactSignals.value(authState) {
  | LoggedIn => true
  | _ => false
  }
})

// Check if current session is in read-only mode
let isReadOnlyMode = (): bool => {
  switch PreactSignals.value(permissionMode) {
  | Some(ReadOnly) => true
  | _ => false
  }
}

// URL bindings for extracting hostname
@new external makeUrl: string => {..} = "URL"

let instanceName: PreactSignals.computed<string> = PreactSignals.computed(() => {
  switch PreactSignals.value(instanceOrigin) {
  | Some(origin) =>
    // Extract hostname from origin
    try {
      let url = makeUrl(origin)
      url["hostname"]
    } catch {
    | _ => origin
    }
  | None => ""
  }
})

// ============================================================
// Actions
// ============================================================

// Persist accounts array to localStorage
let persistAccounts = (accs: array<Account.t>): unit => {
  setStoredValue(storageKeyAccounts, Account.serialize(accs))
}

// Get active account from accounts array
let getActiveAccount = (): option<Account.t> => {
  let id = PreactSignals.value(activeAccountId)
  let accs = PreactSignals.value(accounts)
  switch id {
  | Some(activeId) => accs->Array.find(a => a.id == activeId)
  | None => accs->Array.get(0)
  }
}

// Extract hostname from origin URL
let hostnameFromOrigin = (origin: string): string => {
  try {
    let url = makeUrl(origin)
    url["hostname"]
  } catch {
  | _ => origin
  }
}

// Normalize instance origin (ensure https:// prefix)
let normalizeOrigin = (input: string): string => {
  let trimmed = input->String.trim
  if trimmed->String.startsWith("https://") || trimmed->String.startsWith("http://") {
    trimmed
  } else {
    "https://" ++ trimmed
  }
}

// Login to a Misskey instance with manual token
let login = async (~origin: string, ~token: string): result<unit, loginError> => {
  let normalizedOrigin = normalizeOrigin(origin)

  Console.log2("AppState.login: Logging in to", normalizedOrigin)

  // Set loading state
  PreactSignals.setValue(authState, LoggingIn)

  // Create client
  let newClient = Misskey.connect(normalizedOrigin, ~token)

  // Parallelize ALL initialization calls including currentUser verification
  // Using Promise.all with tuple as recommended by ReScript documentation
  Console.log("AppState.login: Starting parallel authentication and initialization...")
  
  try {
    // Create parameter dict for notifications
    let notifParams = Dict.make()
    notifParams->Dict.set("limit", JSON.Encode.int(30))
    
    // Use Promise.all with tuple to run all promises in parallel
    // Tuples can mix types freely in ReScript
    let (userResult, notificationsResult, antennasResult, listsResult, channelsResult, homeTimelineResult) = await Promise.all6((
      newClient->Misskey.currentUser,
      newClient->Misskey.request(
        "i/notifications",
        ~params=JSON.Encode.object(notifParams),
        (),
      ),
      newClient->Misskey.CustomTimelines.antennas,
      newClient->Misskey.CustomTimelines.lists,
      newClient->Misskey.CustomTimelines.channels,
      newClient->Misskey.Notes.fetch(#home, ~limit=20, ()), // Add home timeline fetch
    ))
    
    // Check if user fetch succeeded
    switch userResult {
    | Ok(user) => {
        Console.log("AppState.login: Parallel initialization complete")
        
        // Store legacy credentials (for backward compat)
        setStoredValue(storageKeyOrigin, normalizedOrigin)
        setStoredValue(storageKeyToken, token)

        // Restore permission mode from storage if available
        let mode = switch getStoredValue(storageKeyPermissionMode) {
        | Some("ReadOnly") => Some(ReadOnly)
        | Some("Standard") => Some(Standard)
        | _ => Some(Standard) // Default to Standard if not set
        }

        // Extract user info for account record
        let userUsername = user->JSON.Decode.object
          ->Option.flatMap(o => o->Dict.get("username"))
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("unknown")
        let userAvatarUrl = user->JSON.Decode.object
          ->Option.flatMap(o => o->Dict.get("avatarUrl"))
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("")
        let userHost = hostnameFromOrigin(normalizedOrigin)

        // Save to multi-account storage
        let accountId = Account.makeId(~origin=normalizedOrigin, ~username=userUsername)
        let accountMode = switch mode {
        | Some(ReadOnly) => Account.ReadOnly
        | _ => Account.Standard
        }
        let account: Account.t = {
          id: accountId,
          origin: normalizedOrigin,
          token,
          username: userUsername,
          host: userHost,
          avatarUrl: userAvatarUrl,
          permissionMode: accountMode,
        }

        // Upsert into accounts array (replace if same ID exists)
        let currentAccounts = PreactSignals.value(accounts)
        let updatedAccounts = switch currentAccounts->Array.findIndex(a => a.id == accountId) {
        | -1 => Array.concat(currentAccounts, [account])
        | idx => currentAccounts->Array.mapWithIndex((a, i) => i == idx ? account : a)
        }
        persistAccounts(updatedAccounts)
        setStoredValue(storageKeyActiveAccountId, accountId)

        // Cache initialization data for components
        AppInitializer.setCache({
          notifications: notificationsResult,
          antennas: antennasResult,
          lists: listsResult,
          channels: channelsResult,
          homeTimeline: Some(homeTimelineResult),
        })

        // Update signals
        PreactSignals.batch(() => {
          PreactSignals.setValue(instanceOrigin, Some(normalizedOrigin))
          PreactSignals.setValue(accessToken, Some(token))
          PreactSignals.setValue(client, Some(newClient))
          PreactSignals.setValue(currentUser, Some(user))
          PreactSignals.setValue(permissionMode, mode)
          PreactSignals.setValue(accounts, updatedAccounts)
          PreactSignals.setValue(activeAccountId, Some(accountId))
          PreactSignals.setValue(authState, LoggedIn)
        })

        // Start idle-time emoji prefetching
        let _ = EmojiStore.prefetchDuringIdle(newClient)

        // Add preconnect hints for the instance
        NetworkOptimizer.addPreconnectForInstance(Some(normalizedOrigin))
        NetworkOptimizer.prefetchCommonDomains(normalizedOrigin)

        // Start notification stream
        NotificationStore.subscribe(newClient)

        // Initialize push notification state
        let _ = PushNotificationStore.restore(newClient, accountId)

        Console.log("AppState.login: Login successful")
        Ok()
      }
    | Error(msg) => {
        Console.error2("AppState.login: Error fetching user", msg)
        let error = InvalidCredentials
        PreactSignals.setValue(authState, LoginFailed(error))
        Error(error)
      }
    }
  } catch {
  | exn => {
      Console.error2("AppState.login: Parallel initialization failed", exn)
      let error = NetworkError("Network error during login")
      PreactSignals.setValue(authState, LoginFailed(error))
      Error(error)
    }
  }
}

// Get permissions based on mode
let getPermissionsForMode = (mode: permissionMode): array<Misskey.MiAuth.permission> => {
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

// Start MiAuth flow with permission mode
let startMiAuth = (~origin: string, ~mode: permissionMode=Standard, ()): unit => {
  let normalizedOrigin = normalizeOrigin(origin)

  let permissions = getPermissionsForMode(mode)

  // Generate auth session
  let session = Misskey.MiAuth.generateUrl(
    ~origin=normalizedOrigin,
    ~name="Kaguya",
    ~permissions,
    ~callback=`${KaguyaNetwork.locationOrigin()}/miauth-callback`,
    (),
  )

  // Store session info and permission mode
  setStoredValue(storageKeyMiAuthSession, session.sessionId)
  setStoredValue(storageKeyMiAuthOrigin, normalizedOrigin)
  setStoredValue(
    storageKeyPermissionMode,
    switch mode {
    | ReadOnly => "ReadOnly"
    | Standard => "Standard"
    },
  )

  // Redirect to auth URL
  Misskey.MiAuth.openUrl(session.authUrl)
}

// Check MiAuth session and complete login
let checkMiAuth = async (): result<unit, loginError> => {
  Console.log("AppState.checkMiAuth: Starting MiAuth session check...")
  let sessionOpt = getStoredValue(storageKeyMiAuthSession)
  let originOpt = getStoredValue(storageKeyMiAuthOrigin)

  Console.log2("AppState.checkMiAuth: Session stored?", sessionOpt->Option.isSome)
  Console.log2("AppState.checkMiAuth: Origin stored?", originOpt->Option.isSome)

  switch (sessionOpt, originOpt) {
  | (Some(sessionId), Some(origin)) => {
      Console.log3("AppState.checkMiAuth: Found session", sessionId, origin)
      PreactSignals.setValue(authState, LoggingIn)

      let checkResult = await Misskey.MiAuth.check(~origin, ~sessionId)

      switch checkResult {
      | Ok({token: Some(token), user: _}) => {
          Console.log("AppState.checkMiAuth: Token received successfully")
          // Clear MiAuth session (but keep permission mode for login function)
          removeStoredValue(storageKeyMiAuthSession)
          removeStoredValue(storageKeyMiAuthOrigin)

          // Login with the token (will restore permission mode from storage)
          let loginResult = await login(~origin, ~token)
          Console.log2("AppState.checkMiAuth: Login result:", loginResult->Result.isOk)
          loginResult
        }
      | Ok({token: None, user: _}) => {
          Console.log("AppState.checkMiAuth: Token is None - auth still pending")
          // Return error so callback page can retry
          let error = UnknownError(
            "Authorization pending. Please complete the authorization process.",
          )
          PreactSignals.setValue(authState, LoggingIn)
          Error(error)
        }
      | Error(msg) => {
          Console.error2("AppState.checkMiAuth: Error", msg)
          let error = InvalidCredentials
          PreactSignals.setValue(authState, LoginFailed(error))
          Error(error)
        }
      }
    }
  | _ => {
      Console.log("AppState.checkMiAuth: Session or origin not found in storage")
      let error = UnknownError("Session information not found. Please try logging in again.")
      PreactSignals.setValue(authState, LoginFailed(error))
      Error(error)
    }
  }
}

// Logout current account (removes from accounts array)
let logout = (): unit => {
  // Remove active account from accounts array
  let currentId = PreactSignals.value(activeAccountId)
  let currentAccounts = PreactSignals.value(accounts)
  let remainingAccounts = switch currentId {
  | Some(id) => currentAccounts->Array.filter(a => a.id != id)
  | None => []
  }
  persistAccounts(remainingAccounts)

  // Remove legacy single-account keys
  removeStoredValue(storageKeyOrigin)
  removeStoredValue(storageKeyToken)
  removeStoredValue(storageKeyPermissionMode)
  removeStoredValue(storageKeyActiveAccountId)

  // Clean up any leftover MiAuth session data
  removeStoredValue(storageKeyMiAuthSession)
  removeStoredValue(storageKeyMiAuthOrigin)

  // Clean up any leftover OAuth2 session data
  removeStoredValue(storageKeyOAuth2CodeVerifier)
  removeStoredValue(storageKeyOAuth2State)
  removeStoredValue(storageKeyOAuth2Origin)
  removeStoredValue(storageKeyOAuth2Scope)

  // Close any existing stream connection
  switch PreactSignals.value(client) {
  | Some(c) => {
      c->Misskey.close
      // Unregister push notifications for this account
      switch currentId {
      | Some(id) => {
          let _ = PushNotificationStore.unsubscribe(c, id)
        }
      | None => ()
      }
    }
  | None => ()
  }

  // Unsubscribe from notifications
  NotificationStore.unsubscribe()
  NotificationStore.clear()

  // Clear emoji cache
  EmojiStore.clear()

  // Clear initialization cache
  AppInitializer.clearCache()

  // Reset all signals
  PreactSignals.batch(() => {
    PreactSignals.setValue(instanceOrigin, None)
    PreactSignals.setValue(accessToken, None)
    PreactSignals.setValue(client, None)
    PreactSignals.setValue(currentUser, None)
    PreactSignals.setValue(permissionMode, None)
    PreactSignals.setValue(accounts, remainingAccounts)
    PreactSignals.setValue(activeAccountId, None)
    PreactSignals.setValue(authState, LoggedOut)
  })
}

// Switch to a different account by ID
let switchAccount = async (accountId: string): result<unit, loginError> => {
  let accs = PreactSignals.value(accounts)
  switch accs->Array.find(a => a.id == accountId) {
  | Some(account) => {
      // Signal that we're switching (keeps existing UI visible during transition)
      PreactSignals.setValue(isSwitchingAccount, true)

      // Tear down current session
      switch PreactSignals.value(client) {
      | Some(c) => c->Misskey.close
      | None => ()
      }
      NotificationStore.unsubscribe()
      NotificationStore.clear()
      EmojiStore.clear()
      AppInitializer.clearCache()

      // Login with the stored account credentials
      setStoredValue(storageKeyActiveAccountId, accountId)
      setStoredValue(
        storageKeyPermissionMode,
        Account.permissionModeToString(account.permissionMode),
      )
      let result = await login(~origin=account.origin, ~token=account.token)
      PreactSignals.setValue(isSwitchingAccount, false)
      result
    }
  | None => Error(UnknownError("Account not found"))
  }
}

// Remove a specific account by ID
let removeAccount = (accountId: string): unit => {
  let currentAccounts = PreactSignals.value(accounts)
  let remaining = currentAccounts->Array.filter(a => a.id != accountId)
  persistAccounts(remaining)
  PreactSignals.setValue(accounts, remaining)

  // If removing the active account, logout
  switch PreactSignals.value(activeAccountId) {
  | Some(id) if id == accountId => {
      // Close current session
      switch PreactSignals.value(client) {
      | Some(c) => c->Misskey.close
      | None => ()
      }
      NotificationStore.unsubscribe()
      NotificationStore.clear()
      EmojiStore.clear()
      AppInitializer.clearCache()

      PreactSignals.batch(() => {
        PreactSignals.setValue(instanceOrigin, None)
        PreactSignals.setValue(accessToken, None)
        PreactSignals.setValue(client, None)
        PreactSignals.setValue(currentUser, None)
        PreactSignals.setValue(permissionMode, None)
        PreactSignals.setValue(activeAccountId, None)
        PreactSignals.setValue(authState, LoggedOut)
      })

      removeStoredValue(storageKeyOrigin)
      removeStoredValue(storageKeyToken)
      removeStoredValue(storageKeyActiveAccountId)
    }
  | _ => ()
  }
}

// ============================================================
// OAuth 2.0 (IndieAuth + PKCE) via openid-client
// ============================================================

// Get scope string based on permission mode
let getScopeForMode = (mode: permissionMode): string => {
  let permissions = getPermissionsForMode(mode)
  permissions->Array.map(Misskey.MiAuth.permissionToString)->Array.join(" ")
}

// Build a proxied fetch function that routes requests through our worker
// to avoid CORS issues with Misskey's well-known/token endpoints
let makeProxiedFetch = (): OpenIDClient.customFetchFn => {
  let proxyBase = KaguyaNetwork.locationOrigin() ++ "/api/oauth-proxy/"
  KaguyaNetwork.makeProxiedFetch(proxyBase)->Obj.magic
}

// Start OAuth2 flow
let startOAuth2 = async (~origin: string, ~mode: permissionMode=Standard, ()): result<unit, loginError> => {
  let normalizedOrigin = normalizeOrigin(origin)
  Console.log2("AppState.startOAuth2: Starting OAuth2 flow for", normalizedOrigin)

  try {
    // The client_id for IndieAuth must match what Misskey's URL parser produces
    // new URL("https://host").href adds a trailing slash
    let clientId = KaguyaNetwork.locationOrigin() ++ "/"

    // Build discovery options with custom fetch that proxies through our worker
    let proxyFetch = makeProxiedFetch()
    let discoveryOptions = OpenIDClient.makeDiscoveryOptions(proxyFetch)

    // Discover OAuth2 endpoints (through proxy to avoid CORS)
    let serverUrl = URL.make(normalizedOrigin)
    let config = await OpenIDClient.discovery(
      serverUrl,
      clientId,
      Nullable.null,
      OpenIDClient.clientAuthNone(),
      discoveryOptions,
    )
    // customFetch only proxies .well-known, token exchange goes direct

    // Generate PKCE values
    let codeVerifier = OpenIDClient.randomPKCECodeVerifier()
    let codeChallenge = await OpenIDClient.calculatePKCECodeChallenge(codeVerifier)
    let state = OpenIDClient.randomState()

    // Build scope
    let scope = getScopeForMode(mode)

    // Store session info for callback
    setStoredValue(storageKeyOAuth2CodeVerifier, codeVerifier)
    setStoredValue(storageKeyOAuth2State, state)
    setStoredValue(storageKeyOAuth2Origin, normalizedOrigin)
    setStoredValue(storageKeyOAuth2Scope, scope)
    setStoredValue(
      storageKeyPermissionMode,
      switch mode {
      | ReadOnly => "ReadOnly"
      | Standard => "Standard"
      },
    )

    // Build redirect URL
    let redirectUri = `${KaguyaNetwork.locationOrigin()}/oauth-callback`

    // Build authorization URL
    let params = Dict.make()
    params->Dict.set("redirect_uri", redirectUri)
    params->Dict.set("scope", scope)
    params->Dict.set("code_challenge", codeChallenge)
    params->Dict.set("code_challenge_method", "S256")
    params->Dict.set("state", state)
    params->Dict.set("response_type", "code")

    let authUrl = OpenIDClient.buildAuthorizationUrl(config, params)

    // Redirect to authorization URL
    Console.log2("AppState.startOAuth2: Redirecting to", URL.href(authUrl))
    Misskey.MiAuth.openUrl(URL.href(authUrl))
    Ok()
  } catch {
  | exn => {
      Console.error2("AppState.startOAuth2: Error", exn)
      let msg = switch exn->JsExn.fromException {
      | Some(jsExn) => JsExn.message(jsExn)->Option.getOr("Unknown error")
      | None => "OAuth2 discovery failed"
      }
      Error(NetworkError(msg))
    }
  }
}

// Check OAuth2 callback and complete login
let checkOAuth2 = async (): result<unit, loginError> => {
  Console.log("AppState.checkOAuth2: Starting OAuth2 callback check...")

  let codeVerifierOpt = getStoredValue(storageKeyOAuth2CodeVerifier)
  let stateOpt = getStoredValue(storageKeyOAuth2State)
  let originOpt = getStoredValue(storageKeyOAuth2Origin)

  switch (codeVerifierOpt, stateOpt, originOpt) {
  | (Some(codeVerifier), Some(expectedState), Some(origin)) => {
      // Clear OAuth2 session data immediately to prevent duplicate requests
      let scopeOpt = getStoredValue(storageKeyOAuth2Scope)
      removeStoredValue(storageKeyOAuth2CodeVerifier)
      removeStoredValue(storageKeyOAuth2State)
      removeStoredValue(storageKeyOAuth2Origin)
      removeStoredValue(storageKeyOAuth2Scope)

      PreactSignals.setValue(authState, LoggingIn)

      try {
        let clientId = KaguyaNetwork.locationOrigin() ++ "/"
        let serverUrl = URL.make(origin)

        // Build proxied fetch for discovery + token exchange
        let proxyFetch = makeProxiedFetch()
        let discoveryOptions = OpenIDClient.makeDiscoveryOptions(proxyFetch)

        // Re-discover to get config (through proxy to avoid CORS)
        let config = await OpenIDClient.discovery(
          serverUrl,
          clientId,
          Nullable.null,
          OpenIDClient.clientAuthNone(),
          discoveryOptions,
        )
        // customFetch only proxies .well-known, token exchange goes direct

        // Get current URL (contains the authorization code)
        let currentUrl = URL.make(KaguyaNetwork.locationHref())

        // Additional token endpoint parameters required by Misskey's IndieAuth
        let tokenParams = Dict.make()
        switch scopeOpt {
        | Some(scope) => tokenParams->Dict.set("scope", scope)
        | None => ()
        }

        // Exchange authorization code for tokens
        let tokens = await OpenIDClient.authorizationCodeGrant(
          config,
          currentUrl,
          {
            "pkceCodeVerifier": codeVerifier,
            "expectedState": expectedState,
          },
          tokenParams,
        )

        Console.log("AppState.checkOAuth2: Token received successfully")

        // Clean up the callback URL before login (removes ?code=... from URL bar)
        KaguyaNetwork.replaceState("/")

        // Login with the obtained token
        let loginResult = await login(~origin, ~token=tokens.access_token)
        loginResult
      } catch {
      | exn => {
          Console.error2("AppState.checkOAuth2: Error", exn)
          let msg = switch exn->JsExn.fromException {
          | Some(jsExn) => JsExn.message(jsExn)->Option.getOr("Unknown error")
          | None => "OAuth2 token exchange failed"
          }
          let error = NetworkError(msg)
          PreactSignals.setValue(authState, LoginFailed(error))
          Error(error)
        }
      }
    }
  | _ => {
      Console.log("AppState.checkOAuth2: OAuth2 session data not found")
      let error = UnknownError("OAuth2のセッション情報が見つかりません。もう一度ログインしてください。")
      PreactSignals.setValue(authState, LoginFailed(error))
      Error(error)
    }
  }
}

// Try to restore session from localStorage on startup
// Handles migration from legacy single-account format
let restoreSession = async (): unit => {
  let storedAccounts = PreactSignals.value(accounts)

  if Array.length(storedAccounts) > 0 {
    // Multi-account path: restore active account
    switch getActiveAccount() {
    | Some(account) => {
        let _ = await login(~origin=account.origin, ~token=account.token)
      }
    | None => ()
    }
  } else {
    // Legacy migration: check old single-account keys
    switch (getStoredValue(storageKeyOrigin), getStoredValue(storageKeyToken)) {
    | (Some(origin), Some(token)) => {
        // login() will auto-save to accounts array
        let _ = await login(~origin, ~token)
      }
    | _ => ()
    }
  }
}

// Get display name of current user
let getCurrentUserName = (): option<string> => {
  switch PreactSignals.value(currentUser) {
  | Some(user) =>
    switch user->JSON.Decode.object {
    | Some(obj) =>
      switch obj->Dict.get("name") {
      | Some(name) => name->JSON.Decode.string
      | None =>
        switch obj->Dict.get("username") {
        | Some(username) => username->JSON.Decode.string
        | None => None
        }
      }
    | None => None
    }
  | None => None
  }
}
