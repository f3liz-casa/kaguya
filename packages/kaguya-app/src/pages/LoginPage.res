// SPDX-License-Identifier: MPL-2.0
// LoginPage.res - Login page with instance URL and token entry

@jsx.component
let make = () => {
  let (instanceUrl, setInstanceUrl) = PreactHooks.useState(() => "")
  let (token, setToken) = PreactHooks.useState(() => "")
  let (isSubmitting, setIsSubmitting) = PreactHooks.useState(() => false)
  let (loginMethod, setLoginMethod) = PreactHooks.useState(() => "oauth2") // "oauth2", "miauth", or "token"
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

  let handleOAuth2Submit = (e: JsxEvent.Form.t) => {
    JsxEvent.Form.preventDefault(e)

    if instanceUrl != "" {
      setIsSubmitting(_ => true)
      let doOAuth2 = async () => {
        let result = await AppState.startOAuth2(~origin=instanceUrl, ~mode=permissionMode, ())
        switch result {
        | Ok() => () // Redirected
        | Error(_) => setIsSubmitting(_ => false)
        }
      }
      let _ = doOAuth2()
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
      | InvalidCredentials => "認証情報が正しくありません。トークンを確認してください。"
      | NetworkError(msg) => "ネットワークエラー: " ++ msg
      | UnknownError(msg) => "エラー: " ++ msg
      },
    )
  | _ => None
  }

  <main className="container login-page">
    <article className="login-card">
      <header>
        <h1 className="login-title"> {Preact.string("かぐや")} </h1>
        <p className="login-subtitle"> {Preact.string("やさしくて、しんぷるな Misskey クライアント")} </p>
      </header>
      <div className="login-method-tabs">
        <button
          className={loginMethod == "oauth2" ? "active" : ""}
          onClick={_ => setLoginMethod(_ => "oauth2")}
          type_="button"
        >
          {Preact.string("OAuth2（おすすめ）")}
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
          {Preact.string("トークン入力")}
        </button>
      </div>

      {switch loginMethod {
      | "oauth2" =>
        <form onSubmit={handleOAuth2Submit}>
          <fieldset>
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
                required=true
              />
              <small> {Preact.string("Misskey インスタンスのアドレス（例: misskey.io）")} </small>
            </label>
            <label htmlFor="permission-mode">
              {Preact.string("権限モード")}
              <select
                id="permission-mode"
                name="permission-mode"
                value={permissionMode == AppState.ReadOnly ? "readonly" : "standard"}
                onChange={handlePermissionModeChange}
              >
                <option value="standard"> {Preact.string("標準（読み書き）")} </option>
                <option value="readonly"> {Preact.string("読み取り専用")} </option>
              </select>
              <small>
                {Preact.string(
                  switch permissionMode {
                  | AppState.ReadOnly => "読み取り専用: タイムラインやプロフィールの閲覧のみ。投稿やリアクションはできません。"
                  | AppState.Standard => "標準: 投稿、リアクション、フォローなど、すべての操作ができます。"
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
          <button type_="submit" disabled={isSubmitting || instanceUrl == ""}>
            {Preact.string(isSubmitting ? "接続中..." : "ログイン")}
          </button>
          <small className="login-help">
            {Preact.string(
              "OAuth2 で安全に認証します。インスタンスが OAuth2 に対応していない場合は MiAuth をお試しください。",
            )}
          </small>
        </form>
      | "miauth" =>
        <form onSubmit={handleMiAuthSubmit}>
          <fieldset>
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
                required=true
              />
              <small> {Preact.string("Misskey インスタンスのアドレス（例: misskey.io）")} </small>
            </label>
            <label htmlFor="permission-mode">
              {Preact.string("権限モード")}
              <select
                id="permission-mode"
                name="permission-mode"
                value={permissionMode == AppState.ReadOnly ? "readonly" : "standard"}
                onChange={handlePermissionModeChange}
              >
                <option value="standard"> {Preact.string("標準（読み書き）")} </option>
                <option value="readonly"> {Preact.string("読み取り専用")} </option>
              </select>
              <small>
                {Preact.string(
                  switch permissionMode {
                  | AppState.ReadOnly => "読み取り専用: タイムラインやプロフィールの閲覧のみ。投稿やリアクションはできません。"
                  | AppState.Standard => "標準: 投稿、リアクション、フォローなど、すべての操作ができます。"
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
            {Preact.string("ログイン")}
          </button>
          <small className="login-help">
            {Preact.string(
              "インスタンスに移動して認証します。トークンを手動で作成する必要はありません。",
            )}
          </small>
        </form>
      | _ =>
        <form onSubmit={handleTokenSubmit}>
          <fieldset>
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
                required=true
              />
              <small> {Preact.string("Misskey インスタンスのアドレス（例: misskey.io）")} </small>
            </label>
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
              <small>
                {Preact.string("インスタンスの 設定 → API からトークンを取得してください")}
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
            {Preact.string(isSubmitting ? "接続中..." : "ログイン")}
          </button>
        </form>
      }}

      <footer>
        <small className="login-help">
          {Preact.string("ヘルプ: インスタンスの設定からアクセストークンを発行できます。")}
        </small>
      </footer>
    </article>
  </main>
}
