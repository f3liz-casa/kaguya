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

let storageKeyOrigin = "kaguya:instanceOrigin"
let storageKeyToken = "kaguya:accessToken"
let storageKeyMiAuthSession = "kaguya:miAuthSession"
let storageKeyMiAuthOrigin = "kaguya:miAuthOrigin"
let storageKeyPermissionMode = "kaguya:permissionMode"

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

// Authentication state
let authState: PreactSignals.signal<authState> = PreactSignals.make(LoggedOut)

// MisskeyJS Client
let client: PreactSignals.signal<option<MisskeyJS.Client.t>> = PreactSignals.make(None)

// Current user info
let currentUser: PreactSignals.signal<option<JSON.t>> = PreactSignals.make(None)

// Permission mode (ReadOnly or Standard)
let permissionMode: PreactSignals.signal<option<permissionMode>> = PreactSignals.make(
  switch getStoredValue(storageKeyPermissionMode) {
  | Some("ReadOnly") => Some(ReadOnly)
  | Some("Standard") => Some(Standard)
  | _ => None
  }
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

// Window bindings for location
module Window = {
  type location = {origin: string}
  @val @scope("window") external location: location = "location"
}

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
  let newClient = MisskeyJS.Client.make(~origin=normalizedOrigin, ~credential=token, ())

  // Setup metrics callback to automatically track all API calls
  MisskeyJS.Client.setMetricsCallback(newClient, metrics => {
    PerfMonitor.trackApiCall(
      ~endpoint=metrics.endpoint,
      ~duration=metrics.durationMs,
      ~success=metrics.success,
    )
  })

  // Try to fetch current user to verify credentials
  Console.log("AppState.login: Fetching current user...")
  let result = await newClient->MisskeyJS.Me.get

  switch result {
  | Ok(user) => {
      Console.log("AppState.login: User fetched successfully")
      // Store credentials
      setStoredValue(storageKeyOrigin, normalizedOrigin)
      setStoredValue(storageKeyToken, token)

      // Restore permission mode from storage if available
      let mode = switch getStoredValue(storageKeyPermissionMode) {
      | Some("ReadOnly") => Some(ReadOnly)
      | Some("Standard") => Some(Standard)
      | _ => Some(Standard) // Default to Standard if not set
      }

      // Update signals
      PreactSignals.batch(() => {
        PreactSignals.setValue(instanceOrigin, Some(normalizedOrigin))
        PreactSignals.setValue(accessToken, Some(token))
        PreactSignals.setValue(client, Some(newClient))
        PreactSignals.setValue(currentUser, Some(user))
        PreactSignals.setValue(permissionMode, mode)
        PreactSignals.setValue(authState, LoggedIn)
      })

      // Start idle-time emoji prefetching
      // This will load emojis when the browser is idle, making the emoji picker feel instant
      let _ = EmojiStore.prefetchDuringIdle(newClient)

      Console.log("AppState.login: Login successful")
      Ok()
    }
  | Error(#APIError(err)) => {
      Console.error3("AppState.login: API Error fetching user", err.message, err.code)
      let error = InvalidCredentials
      PreactSignals.setValue(authState, LoginFailed(error))
      Error(error)
    }
  | Error(#UnknownError(exn)) => {
      let msg = switch exn->Exn.asJsExn {
      | Some(jsExn) => Exn.message(jsExn)->Option.getOr("Unknown error")
      | None => "Unknown error"
      }
      Console.error2("AppState.login: Unknown error fetching user", msg)
      let error = UnknownError(msg)
      PreactSignals.setValue(authState, LoginFailed(error))
      Error(error)
    }
  }
}

// Get permissions based on mode
let getPermissionsForMode = (mode: permissionMode): array<MisskeyJS.MiAuth.permission> => {
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
      #read_clip,
      #read_clip_favorite,
      #read_federation,
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
      #read_clip,
      #write_clip,
      #write_clip_favorite,
      #read_clip_favorite,
    ]
  }
}

// Start MiAuth flow with permission mode
let startMiAuth = (~origin: string, ~mode: permissionMode=Standard, ()): unit => {
  let normalizedOrigin = normalizeOrigin(origin)
  
  let permissions = getPermissionsForMode(mode)
  
  // Generate auth session
  let session = MisskeyJS.MiAuth.generateAuthUrl(
    ~origin=normalizedOrigin,
    ~name="Kaguya",
    ~permissions,
    ~callback=`${Window.location.origin}/miauth-callback`,
    (),
  )
  
  // Store session info and permission mode
  setStoredValue(storageKeyMiAuthSession, session.sessionId)
  setStoredValue(storageKeyMiAuthOrigin, normalizedOrigin)
  setStoredValue(storageKeyPermissionMode, switch mode {
    | ReadOnly => "ReadOnly"
    | Standard => "Standard"
  })
  
  // Redirect to auth URL
  MisskeyJS.MiAuth.openAuthUrl(session.authUrl)
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
      
      let checkResult = await MisskeyJS.MiAuth.check(~origin, ~sessionId)
      
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
           let error = UnknownError("Authorization pending. Please complete the authorization process.")
           PreactSignals.setValue(authState, LoggingIn)
           Error(error)
         }
       | Error(#APIError(err)) => {
           Console.error3("AppState.checkMiAuth: API Error", err.message, err.code)
           let error = InvalidCredentials
           PreactSignals.setValue(authState, LoginFailed(error))
           Error(error)
         }
       | Error(#UnknownError(exn)) => {
           let msg = switch exn->Exn.asJsExn {
           | Some(jsExn) => Exn.message(jsExn)->Option.getOr("Unknown error")
           | None => "Unknown error"
           }
           Console.error2("AppState.checkMiAuth: Unknown error", msg)
           let error = UnknownError(msg)
           PreactSignals.setValue(authState, LoggingIn)
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

// Logout
let logout = (): unit => {
  // Remove all stored credentials and auth data
  removeStoredValue(storageKeyOrigin)
  removeStoredValue(storageKeyToken)
  removeStoredValue(storageKeyPermissionMode)
  
  // Clean up any leftover MiAuth session data
  removeStoredValue(storageKeyMiAuthSession)
  removeStoredValue(storageKeyMiAuthOrigin)

  // Close any existing stream connection
  switch PreactSignals.value(client) {
  | Some(c) => MisskeyJS.Client.close(c)
  | None => ()
  }

  // Clear emoji cache
  EmojiStore.clear()

  // Reset all signals
  PreactSignals.batch(() => {
    PreactSignals.setValue(instanceOrigin, None)
    PreactSignals.setValue(accessToken, None)
    PreactSignals.setValue(client, None)
    PreactSignals.setValue(currentUser, None)
    PreactSignals.setValue(permissionMode, None)
    PreactSignals.setValue(authState, LoggedOut)
  })
}

// Try to restore session from localStorage on startup
let restoreSession = async (): unit => {
  switch (getStoredValue(storageKeyOrigin), getStoredValue(storageKeyToken)) {
  | (Some(origin), Some(token)) => {
      let _ = await login(~origin, ~token)
    }
  | _ => ()
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
