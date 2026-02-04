// SPDX-License-Identifier: MPL-2.0
// Layout.res - Page layout component with header

@jsx.component
let make = (~children: Preact.element) => {
  let instanceName = PreactSignals.value(AppState.instanceName)
  let userName = AppState.getCurrentUserName()->Option.getOr("")
  let isReadOnly = AppState.isReadOnlyMode()
  let navigateWithOptions = Wouter.useNavigateWithOptions()

  let handleLogout = (_: JsxEvent.Mouse.t) => {
    AppState.logout()
    // Navigate to login page after logout with replace to remove from history
    navigateWithOptions("/", {replace: true})
  }

  <div className="layout">
    <header className="container-fluid">
      <nav>
        <ul>
          <li>
            <strong className="app-title"> {Preact.string("Kaguya")} </strong>
            {if instanceName != "" {
              <small className="instance-badge"> {Preact.string(instanceName)} </small>
            } else {
              Preact.null
            }}
          </li>
        </ul>
        <ul>
          <li>
            <Wouter.Link href="/"> {Preact.string("Home")} </Wouter.Link>
          </li>
          <li>
            <Wouter.Link href="/performance"> {Preact.string("Performance")} </Wouter.Link>
          </li>
        </ul>
        <ul>
          {if userName != "" {
            <>
              <li>
                <small> {Preact.string(userName)} </small>
              </li>
              {if isReadOnly {
                <li>
                  <small
                    className="readonly-badge"
                    title="You're in read-only mode. You can view content but cannot post, react, or follow."
                    role="status"
                    ariaLabel="Read-only mode active"
                  >
                    {Preact.string("🔒 Read-Only")}
                  </small>
                </li>
              } else {
                Preact.null
              }}
            </>
          } else {
            Preact.null
          }}
          <li>
            <button className="secondary outline" onClick={handleLogout}>
              {Preact.string("Logout")}
            </button>
          </li>
        </ul>
      </nav>
    </header>
    <main className="container"> {children} </main>
    <footer className="container">
      <small className="footer-text">
        {Preact.string("Kaguya - A warm and simple Misskey client")}
      </small>
    </footer>
  </div>
}
