// SPDX-License-Identifier: MPL-2.0

@jsx.component
let make = () => {
  let pushState = PreactSignals.value(PushNotificationStore.state)
  let clientOpt = PreactSignals.value(AppState.client)
  let activeId = PreactSignals.value(AppState.activeAccountId)

  let handleEnable = (_: JsxEvent.Mouse.t) => {
    switch (clientOpt, activeId) {
    | (Some(c), Some(id)) => {
        let _ = PushNotificationStore.generateScript(c, id)
      }
    | _ => ()
    }
  }

  let handleDisable = (_: JsxEvent.Mouse.t) => {
    switch (clientOpt, activeId) {
    | (Some(c), Some(id)) => {
        let _ = PushNotificationStore.unsubscribe(c, id)
      }
    | _ => ()
    }
  }

  let handleConfirm = (_: JsxEvent.Mouse.t) => {
    activeId->Option.forEach(id => PushNotificationStore.confirmSubscribed(id))
  }

  let handleCopy = (script: string) => (_: JsxEvent.Mouse.t) => {
    let _ = %raw(`navigator.clipboard.writeText(script)`)
  }

  let openScratchpad = (_: JsxEvent.Mouse.t) => {
    let origin = clientOpt->Option.map(Misskey.origin)->Option.getOr("")
    if origin != "" {
      let _ = %raw(`window.open(origin + '/scratchpad', '_blank')`)
    }
  }

  switch pushState {
  | NotSupported =>
    <button className="push-notification-toggle" disabled={true} type_="button">
      {Preact.string("🚫 プッシュ通知未対応")}
    </button>

  | PermissionDenied =>
    <button className="push-notification-toggle" disabled={true} type_="button">
      {Preact.string("🚫 通知が拒否されています")}
    </button>

  | Unsubscribed | Error(_) =>
    <button className="push-notification-toggle" onClick={handleEnable} type_="button">
      {Preact.string(pushState == Unsubscribed ? "🔕 プッシュ通知を有効にする" : "⚠️ プッシュ通知を有効にする")}
    </button>

  | GeneratingScript =>
    <button className="push-notification-toggle" disabled={true} type_="button">
      {Preact.string("⏳ スクリプト生成中...")}
    </button>

  | Subscribed =>
    <button className="push-notification-toggle" onClick={handleDisable} type_="button">
      {Preact.string("🔔 プッシュ通知を無効にする")}
    </button>

  | AwaitingScript(script) =>
    <div className="push-script-container" style={Style.make(~display="flex", ~flexDirection="column", ~gap="8px", ())}>
      <p style={Style.make(~margin="0", ~fontSize="13px", ())}>
        {Preact.string("以下のAiScriptをMisskeyのスクラッチパッドで実行してください：")}
      </p>
      <textarea
        readOnly={true}
        value={script}
        rows={6}
        style={Style.make(~fontFamily="monospace", ~fontSize="11px", ~resize="vertical", ())}
      />
      <div style={Style.make(~display="flex", ~gap="8px", ~flexWrap="wrap", ())}>
        <button onClick={handleCopy(script)} type_="button">
          {Preact.string("📋 コピー")}
        </button>
        <button onClick={openScratchpad} type_="button">
          {Preact.string("🔗 スクラッチパッドを開く")}
        </button>
        <button className="button-primary" onClick={handleConfirm} type_="button">
          {Preact.string("✓ 実行しました")}
        </button>
        <button onClick={handleDisable} type_="button">
          {Preact.string("キャンセル")}
        </button>
      </div>
    </div>
  }
}
