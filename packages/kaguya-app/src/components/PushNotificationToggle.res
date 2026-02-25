// SPDX-License-Identifier: MPL-2.0
// PushNotificationToggle.res - Toggle for enabling/disabling push notifications

@jsx.component
let make = () => {
  let pushState = PreactSignals.value(PushNotificationStore.state)
  let clientOpt = PreactSignals.value(AppState.client)
  let activeId = PreactSignals.value(AppState.activeAccountId)
  let currentUser = PreactSignals.value(AppState.currentUser)

  let userId =
    currentUser
    ->Option.flatMap(JSON.Decode.object)
    ->Option.flatMap(obj => obj->Dict.get("id"))
    ->Option.flatMap(JSON.Decode.string)
    ->Option.getOr("")

  let handleToggle = (_: JsxEvent.Mouse.t) => {
    switch (clientOpt, activeId) {
    | (Some(c), Some(id)) =>
      switch pushState {
      | PushNotificationStore.Subscribed => {
          let _ = PushNotificationStore.unsubscribe(c, id)
        }
      | PushNotificationStore.Unsubscribed
      | PushNotificationStore.Error(_) => {
          let _ = PushNotificationStore.subscribe(c, id)
        }
      | _ => ()
      }
    | _ => ()
    }
  }

  let handleCopyId = (_: JsxEvent.Mouse.t) => {
    if userId != "" {
      let _ = %raw(`navigator.clipboard.writeText(userId)`)
    }
  }

  let (label, icon, disabled) = switch pushState {
  | NotSupported => ("プッシュ通知未対応", "🚫", true)
  | PermissionDenied => ("通知が拒否されています", "🚫", true)
  | Unsubscribed => ("プッシュ通知を有効にする", "🔕", false)
  | Subscribing => ("登録中...", "⏳", true)
  | Subscribed => ("プッシュ通知を無効にする", "🔔", false)
  | Error(_) => ("プッシュ通知を有効にする", "⚠️", false)
  }

  <div className="push-notification-container" style={Style.make(~display="flex", ~flexDirection="column", ~gap="8px", ())}>
    <button
      className="push-notification-toggle"
      onClick={handleToggle}
      disabled
      title={label}
      type_="button"
    >
      {Preact.string(icon ++ " " ++ label)}
    </button>
    {if userId != "" {
      <div style={Style.make(~fontSize="12px", ~opacity="0.7", ~display="flex", ~alignItems="center", ~gap="8px", ())}>
        <span>{Preact.string("Your ID: " ++ userId)}</span>
        <button 
          onClick={handleCopyId}
          style={Style.make(~background="none", ~border="1px solid currentColor", ~borderRadius="4px", ~padding="2px 6px", ~cursor="pointer", ~fontSize="10px", ())}
        >
          {Preact.string("Copy")}
        </button>
      </div>
    } else {
      Preact.null
    }}
  </div>
}
