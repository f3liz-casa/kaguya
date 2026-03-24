// SPDX-License-Identifier: MPL-2.0

@jsx.component
let make = () => {
  let {
    instanceUrl,
    token,
    isSubmitting,
    loginMethod,
    permissionMode,
    errorMessage,
    isSubmitDisabled,
    submitLabel,
    helpText,
    handleInstanceChange,
    handleTokenChange,
    handlePermissionModeChange,
    handleSubmit,
    setLoginMethod,
    validAccounts,
    invalidAccounts,
    isValidating,
    handleSwitchAccount,
    handleRevokeAccount,
  } = LoginPageHook.useLoginForm()

  let (showAddAccount, setShowAddAccount) = PreactHooks.useState(() => false)

  let hasValidAccounts = Array.length(validAccounts) > 0

  <main className="container login-page">
    <article className="login-card">
      <header>
        <h1 className="login-title"> {Preact.string("かぐや")} </h1>
        <p className="login-subtitle"> {Preact.string("やさしくて、しんぷるな Misskey クライアント")} </p>
      </header>

      {if isValidating {
        <div className="login-validating"> {Preact.string("読み込み中...")} </div>
      } else if hasValidAccounts {
        <div className="login-account-switcher">
          {validAccounts
          ->Array.map(account =>
            <button
              key={account.id}
              type_="button"
              className="login-account-item"
              onClick={_ => handleSwitchAccount(account.id)}
            >
              {if account.avatarUrl != "" {
                <img className="login-account-avatar" src={account.avatarUrl} alt="" loading=#lazy />
              } else {
                <div className="login-account-avatar login-account-avatar-placeholder" />
              }}
              <span className="login-account-label"> {Preact.string(Account.displayLabel(account))} </span>
            </button>
          )
          ->Preact.array}
          <button
            type_="button"
            className="login-account-item login-account-add"
            onClick={_ => setShowAddAccount(v => !v)}
          >
            <span className="login-account-add-icon"> {Preact.string("＋")} </span>
            <span> {Preact.string("アカウントを追加")} </span>
          </button>
        </div>
      } else {
        Preact.null
      }}

      {if Array.length(invalidAccounts) > 0 {
        <div className="login-invalid-accounts">
          <p className="login-invalid-accounts-title"> {Preact.string("トークンが無効なアカウント")} </p>
          {invalidAccounts
          ->Array.map(account =>
            <div key={account.id} className="login-invalid-account-item">
              <span> {Preact.string(Account.displayLabel(account))} </span>
              <button
                type_="button"
                className="login-invalid-account-remove"
                onClick={_ => handleRevokeAccount(account.id)}
              >
                {Preact.string("削除")}
              </button>
            </div>
          )
          ->Preact.array}
        </div>
      } else {
        Preact.null
      }}

      {if !isValidating && (!hasValidAccounts || showAddAccount) {
        <form onSubmit={handleSubmit}>
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

          <div className="login-method-tabs">
            <button
              className={loginMethod == #oauth2 ? "active" : ""}
              onClick={_ => setLoginMethod(#oauth2)}
              type_="button"
            >
              {Preact.string("OAuth2")}
            </button>
            <button
              className={loginMethod == #miauth ? "active" : ""}
              onClick={_ => setLoginMethod(#miauth)}
              type_="button"
            >
              {Preact.string("MiAuth")}
            </button>
            <button
              className={loginMethod == #token ? "active" : ""}
              onClick={_ => setLoginMethod(#token)}
              type_="button"
            >
              {Preact.string("トークン")}
            </button>
          </div>

          {if loginMethod == #token {
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
      } else {
        Preact.null
      }}
    </article>
  </main>
}
