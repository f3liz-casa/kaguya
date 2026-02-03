// SPDX-License-Identifier: MPL-2.0
// App.res - Root application component with routing

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

  // Render based on auth state and location
  <>
    <Toast />
    {switch authState {
    | LoggingIn =>
      <main className="container">
        <div className="loading-container">
          <p> {Preact.string("Loading...")} </p>
        </div>
      </main>
     | LoggedIn =>
       // Never show callback page when logged in - the callback should have already redirected
       <Wouter.Switch>
         <Wouter.Route path="/"> <HomePage /> </Wouter.Route>
         <Wouter.Route path="/performance"> <PerformancePage /> </Wouter.Route>
         <Wouter.Route path="/:rest*"> <HomePage /> </Wouter.Route>
       </Wouter.Switch>
     | LoggedOut | LoginFailed(_) => {
         // Check if we're on the callback route
         if location == "/miauth-callback" {
           <MiAuthCallbackPage />
         } else {
           <LoginPage />
         }
       }
    }}
  </>
}
