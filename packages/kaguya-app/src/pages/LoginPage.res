// SPDX-License-Identifier: MPL-2.0

@jsx.component
let make = () => {
  let (instanceUrl, setInstanceUrl) = PreactHooks.useState(() => "")
  let (token, setToken) = PreactHooks.useState(() => "")
  let (isSubmitting, setIsSubmitting) = PreactHooks.useState(() => false)
  let (loginMethod, setLoginMethod) = PreactHooks.useState(() => "oauth2") // "oauth2", "miauth", or "token"
  let (permissionMode, setPermissionMode) = PreactHooks.useState(() => AuthTypes.Standard)

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
    let mode = value == "readonly" ? AuthTypes.ReadOnly : AuthTypes.Standard
    setPermissionMode(_ => mode)
  }

  let handleSubmit = (e: JsxEvent.Form.t) => {
    JsxEvent.Form.preventDefault(e)
    if instanceUrl == "" { () } else {
      switch loginMethod {
      | "miauth" => AuthManager.startMiAuth(~origin=instanceUrl, ~mode=permissionMode, ())
      | "token" =>
        if token != "" {
          setIsSubmitting(_ => true)
          let _ = (async () => {
            let _ = await AuthManager.login(~origin=instanceUrl, ~token)
            setIsSubmitting(_ => false)
          })()
        }
      | _ => // oauth2 (default)
        setIsSubmitting(_ => true)
        let _ = (async () => {
          let result = await AuthManager.startOAuth2(~origin=instanceUrl, ~mode=permissionMode, ())
          switch result {
          | Ok() => ()
          | Error(_) => setIsSubmitting(_ => false)
          }
        })()
      }
    }
  }

  let errorMessage = switch authState {
  | LoginFailed(error) =>
    Some(
      switch error {
      | InvalidCredentials => "認証情報が正しくありません。トークンを確認してください。"
      | NetworkError(msg) => "ネットワークエラー: " ++ msg
      | UnknownError(msg) => "エラー: " ++ msg
      },
    )
  | _ => None
  }

  let isSubmitDisabled = isSubmitting || instanceUrl == "" || (loginMethod == "token" && token == "")

  let submitLabel = switch loginMethod {
  | "token" => isSubmitting ? "接続中..." : "トークンで接続"
  | "miauth" => "MiAuth でログイン"
  | _ => isSubmitting ? "接続中..." : "OAuth2 でログイン"
  }

  let helpText = switch loginMethod {
  | "miauth" => "インスタンスに移動して認証します。トークンを手動で作成する必要はありません。"
  | "token" => "インスタンスの 設定 → API からアクセストークンを取得してください。"
  | _ => "OAuth2 で安全に認証します。インスタンスが OAuth2 に対応していない場合は MiAuth をお試しください。"
  }

  <main className="container login-page">
    <article className="login-card">
      <header>
        <h1 className="login-title"> {Preact.string("かぐや")} </h1>
        <p className="login-subtitle"> {Preact.string("やさしくて、しんぷるな Misskey クライアント")} </p>
      </header>

      <form onSubmit={handleSubmit}>
        // Instance URL — shared across all methods
        <label htmlFor="instance">
          {Preact.string("インスタンス")}
          <input
            type_="text"
            id="instance"
            name="instance"
            placeholder="misskey.io"
            value={instanceUrl}
            onChange={handleInstanceChange}
            disabled={isSubmitting}
            autoFocus=true
            required=true
          />
        </label>

        // Login method tabs
        <div className="login-method-tabs">
          <button
            className={loginMethod == "oauth2" ? "active" : ""}
            onClick={_ => setLoginMethod(_ => "oauth2")}
            type_="button"
          >
            {Preact.string("OAuth2")}
          </button>
          <button
            className={loginMethod == "miauth" ? "active" : ""}
            onClick={_ => setLoginMethod(_ => "miauth")}
            type_="button"
          >
            {Preact.string("MiAuth")}
          </button>
          <button
            className={loginMethod == "token" ? "active" : ""}
            onClick={_ => setLoginMethod(_ => "token")}
            type_="button"
          >
            {Preact.string("トークン")}
          </button>
        </div>

        // Token input — only for token method
        {if loginMethod == "token" {
          <label htmlFor="token">
            {Preact.string("アクセストークン")}
            <input
              type_="password"
              id="token"
              name="token"
              placeholder="アクセストークン"
              value={token}
              onChange={handleTokenChange}
              disabled={isSubmitting}
              required=true
            />
          </label>
        } else {
          // Permission mode — for OAuth2 and MiAuth only
          <label htmlFor="permission-mode">
            {Preact.string("権限モード")}
            <select
              id="permission-mode"
              name="permission-mode"
              value={permissionMode == AuthTypes.ReadOnly ? "readonly" : "standard"}
              onChange={handlePermissionModeChange}
            >
              <option value="standard"> {Preact.string("標準（読み書き）")} </option>
              <option value="readonly"> {Preact.string("読み取り専用")} </option>
            </select>
          </label>
        }}

        {switch errorMessage {
        | Some(msg) =>
          <div className="error-message" role="alert">
            <p> {Preact.string(msg)} </p>
          </div>
        | None => Preact.null
        }}

        <button type_="submit" disabled={isSubmitDisabled}>
          {Preact.string(submitLabel)}
        </button>

        <small className="login-help"> {Preact.string(helpText)} </small>
      </form>
    </article>
  </main>
}
