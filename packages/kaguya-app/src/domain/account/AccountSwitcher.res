// SPDX-License-Identifier: MPL-2.0

@jsx.component
let make = () => {
  let (isOpen, setIsOpen) = PreactHooks.useState(() => false)
  let accounts = PreactSignals.value(AppState.accounts)
  let activeId = PreactSignals.value(AppState.activeAccountId)
  let userName = AppState.getCurrentUserName()->Option.getOr("")
  let isReadOnly = AppState.isReadOnlyMode()
  let navigateWithOptions = Wouter.useNavigateWithOptions()

  let dropdownRef = PreactHooks.useRef(Nullable.null)

  PreactHooks.useEffect1(() => {
    if isOpen {
      let handleClick = (e: JsxEvent.Mouse.t) => {
        let target: Dom.element = e->JsxEvent.Mouse.target->Obj.magic
        switch dropdownRef.current->Nullable.toOption {
        | Some(el) =>
          if !(el->Obj.magic)["contains"](target) {
            setIsOpen(_ => false)
          }
        | None => ()
        }
      }
      Document.addEventListener("click", handleClick)
      Some(() => Document.removeEventListener("click", handleClick))
    } else {
      None
    }
  }, [isOpen])

  let handleToggle = (_: JsxEvent.Mouse.t) => {
    setIsOpen(prev => !prev)
  }

  let handleLogout = (_: JsxEvent.Mouse.t) => {
    setIsOpen(_ => false)
    AuthManager.logout()
    navigateWithOptions("/", {replace: true})
  }

  let handleSwitch = (accountId: string) => {
    ((_: JsxEvent.Mouse.t) => {
      setIsOpen(_ => false)
      let _ = AuthManager.switchAccount(accountId)
    })
  }

  let handleRemove = (accountId: string) => {
    ((e: JsxEvent.Mouse.t) => {
      e->JsxEvent.Mouse.stopPropagation
      AccountManager.removeAccount(accountId)
      if Array.length(PreactSignals.value(AppState.accounts)) == 0 {
        navigateWithOptions("/", {replace: true})
      }
    })
  }

  let handleAddAccount = (_: JsxEvent.Mouse.t) => {
    setIsOpen(_ => false)
    navigateWithOptions("/add-account", {replace: false})
  }

  let (activeHandle, activeInstance, activeAvatarUrl) = switch activeId->Option.flatMap(id => accounts->Array.find(a => a.id == id)) {
  | Some(a) => ("@" ++ a.username, a.host, a.avatarUrl)
  | None => (userName, "", "")
  }

  <div className="account-switcher" ref={Obj.magic(dropdownRef)}>
    <button
      className="account-switcher-trigger"
      onClick={handleToggle}
      ariaExpanded={isOpen}
      ariaLabel="アカウントメニュー"
      type_="button"
    >
      {if activeAvatarUrl != "" {
        <img
          className="account-switcher-trigger-avatar"
          src={activeAvatarUrl}
          alt=""
          loading=#lazy
        />
      } else {
        <div className="account-switcher-trigger-avatar account-switcher-avatar-placeholder" />
      }}
      <div className="account-switcher-trigger-info">
        <span className="account-switcher-name">
          {Preact.string(activeHandle)}
        </span>
        {if activeInstance != "" {
          <span className="account-switcher-trigger-instance">
            {Preact.string(activeInstance)}
          </span>
        } else {
          Preact.null
        }}
      </div>
      {if isReadOnly {
        <span className="readonly-badge-small"> {Preact.string("🔒")} </span>
      } else {
        Preact.null
      }}
      <span className="account-switcher-arrow" ariaHidden={true}>
        {Preact.string("▼")}
      </span>
    </button>

    {if isOpen {
      <div className="account-switcher-dropdown" role="menu">
        // Active account (always shown at top)
        {switch activeId->Option.flatMap(id => accounts->Array.find(a => a.id == id)) {
        | Some(active) =>
          <div className="account-switcher-item account-switcher-active">
            {if active.avatarUrl != "" {
              <img
                className="account-switcher-avatar"
                src={active.avatarUrl}
                alt=""
                loading=#lazy
              />
            } else {
              <div className="account-switcher-avatar account-switcher-avatar-placeholder" />
            }}
            <div className="account-switcher-info">
              <span className="account-switcher-active-name">
                <MfmRenderer text={userName} parseSimple=true />
              </span>
              <span className="account-switcher-handle">
                {Preact.string(Account.displayLabel(active))}
              </span>
            </div>
            {if isReadOnly {
              <span className="readonly-badge-small" title="読み取り専用"> {Preact.string("🔒")} </span>
            } else {
              <span className="account-switcher-active-check" ariaHidden={true}> {Preact.string("✓")} </span>
            }}
          </div>
        | None => Preact.null
        }}

        // Other accounts
        {let otherAccounts = accounts->Array.filter(a => Some(a.id) != activeId)
        if Array.length(otherAccounts) > 0 {
          <>
            <div className="account-switcher-divider" />
            {otherAccounts
            ->Array.map(account => {
              <div
                key={account.id}
                className="account-switcher-item"
                role="menuitem"
                onClick={handleSwitch(account.id)}
              >
                {if account.avatarUrl != "" {
                  <img
                    className="account-switcher-avatar"
                    src={account.avatarUrl}
                    alt=""
                    loading=#lazy
                  />
                } else {
                  <div className="account-switcher-avatar account-switcher-avatar-placeholder" />
                }}
                <span className="account-switcher-label">
                  {Preact.string(Account.displayLabel(account))}
                </span>
                <button
                  className="account-switcher-remove"
                  onClick={handleRemove(account.id)}
                  ariaLabel={"アカウントを削除: " ++ Account.displayLabel(account)}
                  type_="button"
                >
                  {Preact.string("×")}
                </button>
              </div>
            })
            ->Preact.array}
          </>
        } else {
          Preact.null
        }}

        <div className="account-switcher-divider" />
        <div className="account-switcher-item account-switcher-add" role="menuitem" onClick={handleAddAccount}>
          <span className="account-switcher-add-icon"> {Preact.string("＋")} </span>
          <span> {Preact.string("アカウントを追加")} </span>
        </div>

        // Push notification toggle
        <div className="account-switcher-divider" />
        <div className="account-switcher-item">
          <PushNotificationToggle />
        </div>
        {if isReadOnly {
          <div className="account-switcher-item" style={Style.make(~fontSize="12px", ~opacity="0.8", ())}>
            <Wouter.Link href="/settings/push-manual" onClick={_ => setIsOpen(_ => false)}>
              {Preact.string("⚙️ プッシュ通知の手動設定")}
            </Wouter.Link>
          </div>
        } else {
          Preact.null
        }}

        // Logout
        <div className="account-switcher-divider" />
        <div className="account-switcher-item account-switcher-logout" role="menuitem" onClick={handleLogout}>
          <span> {Preact.string("ログアウト")} </span>
        </div>
      </div>
    } else {
      Preact.null
    }}
  </div>
}
