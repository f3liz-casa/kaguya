// SPDX-License-Identifier: MPL-2.0
// Layout.res - Page layout component with header

@jsx.component
let make = (~children: Preact.element) => {
  let instanceName = PreactSignals.value(AppState.instanceName)

  let unreadCount = PreactSignals.value(NotificationStore.unreadCount)

  let (location, navigate) = Wouter.useLocation()

  let isActive = (path: string) => location == path

  // Initialize theme on mount
  PreactHooks.useEffect0(() => {
    ThemeStore.init()
    None
  })

  let _theme = PreactSignals.value(ThemeStore.currentTheme)
  let darkMode = ThemeStore.isDark()

  let handleThemeToggle = (_: JsxEvent.Mouse.t) => {
    ThemeStore.toggle()
  }

  // Compose modal state
  let (showCompose, setShowCompose) = PreactHooks.useState(() => false)

  let handleOverlayClick = (e: JsxEvent.Mouse.t) => {
    let target = JsxEvent.Mouse.target(e)
    let currentTarget = JsxEvent.Mouse.currentTarget(e)
    if target == currentTarget {
      setShowCompose(_ => false)
    }
  }

  <div className="layout">
    <nav className="left-sidebar" ariaLabel="サイドナビゲーション">
      <Wouter.Link href="/" className="sidebar-logo">
        <div className="sidebar-logo-icon"> {Preact.string("🌿")} </div>
      </Wouter.Link>
      <div className="sidebar-nav-items">
        <button
          className={"sidebar-nav-btn" ++ (if isActive("/") { " active" } else { "" })}
          onClick={_ => navigate("/")}
          title="ホーム"
          ariaLabel="ホーム"
          type_="button"
        >
          <iconify-icon icon="tabler:home" />
        </button>
        <button
          className={"sidebar-nav-btn" ++ (if isActive("/notifications") { " active" } else { "" })}
          onClick={_ => navigate("/notifications")}
          title="通知"
          ariaLabel="通知"
          type_="button"
        >
          <iconify-icon icon="tabler:bell" />
          {if unreadCount > 0 {
            <span className="sidebar-notification-badge">
              {Preact.string(if unreadCount > 99 { "99+" } else { Int.toString(unreadCount) })}
            </span>
          } else {
            Preact.null
          }}
        </button>
      </div>
      <div className="sidebar-bottom">
        <button
          className="sidebar-nav-btn theme-toggle-sidebar"
          onClick={handleThemeToggle}
          title={if darkMode { "ライトモードに切り替え" } else { "ダークモードに切り替え" }}
          ariaLabel={if darkMode { "ライトモードに切り替え" } else { "ダークモードに切り替え" }}
          type_="button"
        >
          <iconify-icon icon={if darkMode { "tabler:sun" } else { "tabler:moon" }} />
        </button>
        <button
          className={"sidebar-nav-btn" ++ (if isActive("/settings") { " active" } else { "" })}
          onClick={_ => navigate("/settings")}
          title="設定"
          ariaLabel="設定"
          type_="button"
        >
          <iconify-icon icon="tabler:settings" />
        </button>
      </div>
    </nav>

    <div className="layout-main">
      <header className="container-fluid">
        <nav>
          <ul>
            <li>
              <Wouter.Link href="/" className="header-logo-link">
                <span className="header-leaf-icon"> {Preact.string("🌿")} </span>
              </Wouter.Link>
              <strong className="app-title"> {Preact.string("かぐや")} </strong>
              {if instanceName != "" {
                <small className="instance-badge"> {Preact.string(instanceName)} </small>
              } else {
                Preact.null
              }}
            </li>
          </ul>
          <ul>
            <li>
              <Wouter.Link href="/" className={"header-nav-link" ++ (if isActive("/") { " active" } else { "" })}>
                {Preact.string("ホーム")}
              </Wouter.Link>
            </li>
            <li>
              <Wouter.Link href="/notifications" className={"notification-bell header-nav-link" ++ (if isActive("/notifications") { " active" } else { "" })}>
                {Preact.string("🔔")}
                {if unreadCount > 0 {
                  <span className="notification-badge">
                    {Preact.string(
                      if unreadCount > 99 { "99+" } else { Int.toString(unreadCount) }
                    )}
                  </span>
                } else {
                  Preact.null
                }}
              </Wouter.Link>
            </li>
          </ul>
          <ul>
            <li>
              <button
                className="theme-toggle-btn"
                onClick={handleThemeToggle}
                title={if darkMode { "ライトモードに切り替え" } else { "ダークモードに切り替え" }}
                ariaLabel={if darkMode { "ライトモードに切り替え" } else { "ダークモードに切り替え" }}
                type_="button"
              >
                <iconify-icon icon={if darkMode { "tabler:sun" } else { "tabler:moon" }} />
              </button>
            </li>
            <li>
              <AccountSwitcher />
            </li>
          </ul>
        </nav>
      </header>
      <main className="container"> {children} </main>
      <footer className="container">
        <small className="footer-text">
          {Preact.string("かぐや — やさしい Misskey クライアント")}
        </small>
      </footer>
    </div>

    <nav className="bottom-nav" ariaLabel="ボトムナビゲーション">
      <button
        className={"bottom-nav-btn" ++ (if isActive("/") { " active" } else { "" })}
        onClick={_ => navigate("/")}
        title="ホーム"
        ariaLabel="ホーム"
        type_="button"
      >
        <iconify-icon icon="tabler:home" />
      </button>
      <button
        className={"bottom-nav-btn" ++ (if isActive("/notifications") { " active" } else { "" })}
        onClick={_ => navigate("/notifications")}
        title="通知"
        ariaLabel="通知"
        type_="button"
      >
        <span className="bottom-nav-bell-wrapper">
          <iconify-icon icon="tabler:bell" />
          {if unreadCount > 0 {
            <span className="notification-badge">
              {Preact.string(if unreadCount > 99 { "99+" } else { Int.toString(unreadCount) })}
            </span>
          } else {
            Preact.null
          }}
        </span>
      </button>
      <button
        className={"bottom-nav-btn" ++ (if isActive("/settings") { " active" } else { "" })}
        onClick={_ => navigate("/settings")}
        title="設定"
        ariaLabel="設定"
        type_="button"
      >
        <iconify-icon icon="tabler:settings" />
      </button>
    </nav>

    <button
      className="note-fab"
      type_="button"
      onClick={_ => setShowCompose(_ => true)}
      title="ノートを書く"
      ariaLabel="ノートを書く"
    >
      <iconify-icon icon="tabler:pencil-plus" />
    </button>

    {if showCompose {
      <div className="compose-overlay" onClick={handleOverlayClick}>
        <div className="compose-modal">
          <div className="compose-modal-header">
            <span className="compose-modal-title"> {Preact.string("ノートを書く")} </span>
            <button
              type_="button"
              className="compose-close-btn"
              onClick={_ => setShowCompose(_ => false)}
              ariaLabel="閉じる"
            >
              <iconify-icon icon="tabler:x" />
            </button>
          </div>
          <PostForm onPosted={_ => setShowCompose(_ => false)} />
        </div>
      </div>
    } else {
      Preact.null
    }}
  </div>
}
