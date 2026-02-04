// SPDX-License-Identifier: MPL-2.0
// LoginPage.res - Login page with instance URL and token entry

@jsx.component
let make = () => {
  let (instanceUrl, setInstanceUrl) = PreactHooks.useState(() => "")
  let (token, setToken) = PreactHooks.useState(() => "")
  let (isSubmitting, setIsSubmitting) = PreactHooks.useState(() => false)
  let (loginMethod, setLoginMethod) = PreactHooks.useState(() => "miauth") // "miauth" or "token"
  let (permissionMode, setPermissionMode) = PreactHooks.useState(() => AppState.Standard) // ReadOnly or Standard

  let authState = PreactSignals.value(AppState.authState)

  let handleInstanceChange = (e: JsxEvent.Form.t) => {
    let value = JsxEvent.Form.target(e)["value"]
    setInstanceUrl(_ => value)
  }

  let handleTokenChange = (e: JsxEvent.Form.t) => {
    let value = JsxEvent.Form.target(e)["value"]
    setToken(_ => value)
  }

  let handlePermissionModeChange = (e: JsxEvent.Form.t) => {
    let value = JsxEvent.Form.target(e)["value"]
    let mode = value == "readonly" ? AppState.ReadOnly : AppState.Standard
    setPermissionMode(_ => mode)
  }

  let handleMiAuthSubmit = (e: JsxEvent.Form.t) => {
    JsxEvent.Form.preventDefault(e)

    if instanceUrl != "" {
      AppState.startMiAuth(~origin=instanceUrl, ~mode=permissionMode, ())
    }
  }

  let handleTokenSubmit = (e: JsxEvent.Form.t) => {
    JsxEvent.Form.preventDefault(e)

    if instanceUrl != "" && token != "" {
      setIsSubmitting(_ => true)

      let doLogin = async () => {
        let _ = await AppState.login(~origin=instanceUrl, ~token)
        setIsSubmitting(_ => false)
      }

      let _ = doLogin()
    }
  }

  let errorMessage = switch authState {
  | LoginFailed(error) =>
    Some(
      switch error {
      | InvalidCredentials => "Invalid credentials. Please check your token."
      | NetworkError(msg) => "Network error: " ++ msg
      | UnknownError(msg) => "Error: " ++ msg
      },
    )
  | _ => None
  }

  <main className="container login-page">
    <article className="login-card">
      <header>
        <h1 className="login-title"> {Preact.string("Kaguya")} </h1>
        <p className="login-subtitle"> {Preact.string("A warm and simple Misskey client")} </p>
      </header>
      <div className="login-method-tabs">
        <button
          className={loginMethod == "miauth" ? "active" : ""}
          onClick={_ => setLoginMethod(_ => "miauth")}
          type_="button"
        >
          {Preact.string("MiAuth (Recommended)")}
        </button>
        <button
          className={loginMethod == "token" ? "active" : ""}
          onClick={_ => setLoginMethod(_ => "token")}
          type_="button"
        >
          {Preact.string("Manual Token")}
        </button>
      </div>

      {switch loginMethod {
      | "miauth" =>
        <form onSubmit={handleMiAuthSubmit}>
          <fieldset>
            <label htmlFor="instance">
              {Preact.string("Instance URL")}
              <input
                type_="text"
                id="instance"
                name="instance"
                placeholder="misskey.io"
                value={instanceUrl}
                onChange={handleInstanceChange}
                disabled={isSubmitting}
                required=true
              />
              <small> {Preact.string("Enter your Misskey instance (e.g., misskey.io)")} </small>
            </label>
            <label htmlFor="permission-mode">
              {Preact.string("Permission Mode")}
              <select
                id="permission-mode"
                name="permission-mode"
                value={permissionMode == AppState.ReadOnly ? "readonly" : "standard"}
                onChange={handlePermissionModeChange}
              >
                <option value="standard"> {Preact.string("Standard (read + write)")} </option>
                <option value="readonly"> {Preact.string("Read-only (view only)")} </option>
              </select>
              <small>
                {Preact.string(
                  switch permissionMode {
                  | AppState.ReadOnly => "Read-only mode: View timelines, profiles, and content. Cannot post, react, or follow."
                  | AppState.Standard => "Standard mode: Full access to post, react, follow, and manage your account."
                  },
                )}
              </small>
            </label>
          </fieldset>
          {switch errorMessage {
          | Some(msg) =>
            <div className="error-message" role="alert">
              <p> {Preact.string(msg)} </p>
            </div>
          | None => Preact.null
          }}
          <button type_="submit" disabled={instanceUrl == ""}>
            {Preact.string("Login with MiAuth")}
          </button>
          <small className="login-help">
            {Preact.string(
              "You'll be redirected to your instance to authorize this app. No need to manually create a token!",
            )}
          </small>
        </form>
      | _ =>
        <form onSubmit={handleTokenSubmit}>
          <fieldset>
            <label htmlFor="instance">
              {Preact.string("Instance URL")}
              <input
                type_="text"
                id="instance"
                name="instance"
                placeholder="misskey.io"
                value={instanceUrl}
                onChange={handleInstanceChange}
                disabled={isSubmitting}
                required=true
              />
              <small> {Preact.string("Enter your Misskey instance (e.g., misskey.io)")} </small>
            </label>
            <label htmlFor="token">
              {Preact.string("Access Token")}
              <input
                type_="password"
                id="token"
                name="token"
                placeholder="Your access token"
                value={token}
                onChange={handleTokenChange}
                disabled={isSubmitting}
                required=true
              />
              <small>
                {Preact.string("Get your token from Settings > API in your Misskey instance")}
              </small>
            </label>
          </fieldset>
          {switch errorMessage {
          | Some(msg) =>
            <div className="error-message" role="alert">
              <p> {Preact.string(msg)} </p>
            </div>
          | None => Preact.null
          }}
          <button type_="submit" disabled={isSubmitting || instanceUrl == "" || token == ""}>
            {Preact.string(isSubmitting ? "Connecting..." : "Login")}
          </button>
        </form>
      }}

      <footer>
        <small className="login-help">
          {Preact.string("Need help? Visit your instance's settings to generate an access token.")}
        </small>
      </footer>
    </article>
  </main>
}
