// SPDX-License-Identifier: MPL-2.0
// Native Misskey push is now handled automatically via PushNotificationToggle.
// This page is no longer needed.

@jsx.component
let make = () => {
  <Layout>
    <div style={Style.make(~padding="20px", ())}>
      <p>{Preact.string("プッシュ通知はネイティブMisskey方式に移行しました。設定から有効にしてください。")}</p>
      <Wouter.Link href="/settings">{Preact.string("← 設定へ")}</Wouter.Link>
    </div>
  </Layout>
}
