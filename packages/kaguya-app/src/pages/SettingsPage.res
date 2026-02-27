// SPDX-License-Identifier: MPL-2.0

@jsx.component
let make = () => {
  <Layout>
    <div className="settings-page">
      <h2 className="settings-title"> {Preact.string("設定")} </h2>

      <section className="settings-section">
        <h3 className="settings-section-title"> {Preact.string("アカウント")} </h3>
        <div className="settings-card">
          <AccountSwitcher />
        </div>
      </section>

      <section className="settings-section">
        <h3 className="settings-section-title"> {Preact.string("通知")} </h3>
        <div className="settings-card settings-card-row">
          <span className="settings-card-label"> {Preact.string("プッシュ通知")} </span>
          <PushNotificationToggle />
        </div>
      </section>
    </div>
  </Layout>
}
