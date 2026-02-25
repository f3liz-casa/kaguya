// SPDX-License-Identifier: MPL-2.0
// App.res - Root application component with routing

// Route wrapper components to extract params from wouter
module NotePageRoute = {
  @jsx.component
  let make = () => {
    let params = Wouter.useParams()
    let noteId = params->Dict.get("noteId")->Option.getOr("")
    let host = params->Dict.get("host")->Option.getOr("")
    <NotePage noteId host />
  }
}

// Parse user acct string: "username" or "username@host"
let parseAcct = (acct: string): (string, option<string>) => {
  switch acct->String.indexOf("@") {
  | -1 => (acct, None)
  | idx => (
      acct->String.slice(~start=0, ~end=idx),
      Some(acct->String.slice(~start=idx + 1, ~end=String.length(acct))),
    )
  }
}

// Catch-all route: handles /@user paths and fallback to HomePage
module CatchAllRoute = {
  @jsx.component
  let make = () => {
    let (location, _) = Wouter.useLocation()
    if location->String.startsWith("/@") {
      let acct = location->String.slice(~start=2, ~end=String.length(location))
      let (username, host) = parseAcct(acct)
      <UserPage username ?host />
    } else {
      <HomePage />
    }
  }
}

@jsx.component
let make = () => {
  // Get current location early
  let (location, _) = Wouter.useLocation()

  // Restore session on mount
  PreactHooks.useEffect0(() => {
    let _ = AppState.restoreSession()
    None
  })

  // Subscribe to auth state
  let authState = PreactSignals.value(AppState.authState)
  let isSwitchingAccount = PreactSignals.value(AppState.isSwitchingAccount)

  // The logged-in routes (shared between LoggedIn and account-switch loading states)
  let loggedInRoutes =
    <Wouter.Switch>
      <Wouter.Route path="/">
        <HomePage />
      </Wouter.Route>
      <Wouter.Route path="/notifications">
        <NotificationsPage />
      </Wouter.Route>
      <Wouter.Route path="/performance">
        <PerformancePage />
      </Wouter.Route>
      <Wouter.Route path="/add-account">
        <LoginPage />
      </Wouter.Route>
      <Wouter.Route path="/settings/push-manual">
        <PushManualRegistrationPage />
      </Wouter.Route>
      <Wouter.Route path="/settings">
        <SettingsPage />
      </Wouter.Route>
      <Wouter.Route path="/notes/:noteId/:host">
        <NotePageRoute />
      </Wouter.Route>
      <Wouter.Route path="/notes">
        <Layout>
          <div className="loading-container">
            <p> {Preact.string("ノートを選択してください")} </p>
          </div>
        </Layout>
      </Wouter.Route>
      <Wouter.Route path="/:rest*">
        <CatchAllRoute />
      </Wouter.Route>
    </Wouter.Switch>

  // Render based on auth state and location
  <>
    <Toast />
    {switch authState {
    | LoggingIn =>
      if location == "/miauth-callback" {
        <MiAuthCallbackPage />
      } else if location->String.startsWith("/oauth-callback") {
        <OAuthCallbackPage />
      } else if isSwitchingAccount {
        // Keep showing the current content during account switch (seamless transition)
        loggedInRoutes
      } else {
        // Initial session restore — show loading spinner
        <main className="container">
          <div className="loading-container">
            <p> {Preact.string("読み込み中...")} </p>
          </div>
        </main>
      }
    | LoggedIn => loggedInRoutes
    | LoggedOut | LoginFailed(_) => // Check if we're on a callback route
      if location == "/miauth-callback" {
        <MiAuthCallbackPage />
      } else if location->String.startsWith("/oauth-callback") {
        <OAuthCallbackPage />
      } else {
        <LoginPage />
      }
    }}
  </>
}
