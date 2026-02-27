// SPDX-License-Identifier: MPL-2.0

@jsx.component
let make = () => {
  let currentUser = PreactSignals.value(AppState.currentUser)
  let clientOpt = PreactSignals.value(AppState.client)
  
  let (subscriptionJson, setSubscriptionJson) = PreactHooks.useState(() => "")
  let (webhookSecret, setWebhookSecret) = PreactHooks.useState(() => "")
  let (serverGeneratedId, setServerGeneratedId) = PreactHooks.useState(() => None)
  let (isRegistering, setIsRegistering) = PreactHooks.useState(() => false)
  let (error, setError) = PreactHooks.useState(() => None)

  let userId =
    currentUser
    ->Option.flatMap(JSON.Decode.object)
    ->Option.flatMap(obj => obj->Dict.get("id"))
    ->Option.flatMap(JSON.Decode.string)
    ->Option.getOr("")

  let origin = clientOpt->Option.map(Misskey.origin)->Option.getOr("")

  // Generate random secret on mount
  PreactHooks.useEffect0(() => {
    setWebhookSecret(_ => %raw(`crypto.randomUUID()`))
    None
  })

  let handleGenerateSubscription = async () => {
    if ServiceWorkerAPI.isSupported() && ServiceWorkerAPI.isNotificationSupported() {
      setError(_ => None)
      try {
        // Request permission (must be triggered by user gesture)
        let perm = await ServiceWorkerAPI.requestPermission()
        if perm == #granted {
          let registration = await ServiceWorkerAPI.register("/sw.js")
          let pm = ServiceWorkerAPI.pushManager(registration)
          
          let existingSub = await ServiceWorkerAPI.getSubscription(pm)
          let subscription = switch existingSub->Nullable.toOption {
          | Some(sub) => sub
          | None => {
              let opts = ServiceWorkerAPI.makeSubscribeOptions(PushNotificationStore.pushServerVapidKey)
              await ServiceWorkerAPI.subscribe(pm, opts)
            }
          }

          let subJSON = ServiceWorkerAPI.toJSON(subscription)
          setSubscriptionJson(_ => JSON.stringifyAny(subJSON)->Option.getOr(""))
        } else {
          setError(_ => Some("Notification permission denied. Please allow notifications in your browser settings."))
        }
      } catch {
      | exn => {
          let msg = switch exn->JsExn.fromException {
          | Some(jsExn) => JsExn.message(jsExn)->Option.getOr("Unknown error")
          | None => "Unknown error"
          }
          setError(_ => Some("Failed to generate subscription: " ++ msg))
        }
      }
    } else {
      setError(_ => Some("Push notifications are not supported in this browser."))
    }
  }

  let handleRegister = async () => {
    setIsRegistering(_ => true)
    setError(_ => None)
    
    try {
      let body = {
        "misskey_origin": origin,
        "webhook_user_id": userId,
        "webhook_secret": webhookSecret,
        "push_subscription": JSON.parseOrThrow(subscriptionJson)->Obj.magic,
        "notification_preference": "quiet",
        "delay_minutes": 1,
      }

      let response = await PushNotificationStore.fetch(
        PushNotificationStore.pushServerUrl ++ "/register",
        {
          "method": "POST",
          "headers": {"Content-Type": "application/json"},
          "body": JSON.stringifyAny(body)->Option.getOr("{}"),
        },
      )

      if (response["ok"]: bool) {
        let json = await %raw(`response.json()`)
        let sid = (json["id"]: string)
        setServerGeneratedId(_ => Some(sid))
        let accountId = PreactSignals.value(AppState.activeAccountId)->Option.getOr("")
        PushNotificationStore.setItem(PushNotificationStore.storageKeyPrefix ++ accountId, "true")
        PushNotificationStore.setItem(PushNotificationStore.serverUserIdPrefix ++ accountId, sid)
        PushNotificationStore.setItem(PushNotificationStore.webhookSecretPrefix ++ accountId, webhookSecret)
        PreactSignals.setValue(PushNotificationStore.state, PushNotificationStore.Subscribed)
      } else {
        setError(_ => Some("Server returned an error during registration."))
      }
    } catch {
    | _ => setError(_ => Some("Failed to connect to push server."))
    }
    setIsRegistering(_ => false)
  }

  let copyToClipboard = (text: string) => {
    let _ = %raw(`navigator.clipboard.writeText(arguments[0])`)(text)
  }

  <Layout>
    <div className="manual-push-page">
      <h1> {Preact.string("Manual Push Registration")} </h1>
      <p> 
        {Preact.string("This page allows you to manually register for push notifications. This is useful for read-only accounts or if you want to manually create a webhook on your Misskey instance for privacy reasons.")} 
      </p>

      <section className="manual-push-section">
        <h2> {Preact.string("Step 1: Initialize Browser Subscription")} </h2>
        <p> {Preact.string("Click below to prepare your browser for receiving push notifications.")} </p>
        <button 
          onClick={_ => { let _ = handleGenerateSubscription() }}
          disabled={subscriptionJson != ""}
        >
          {Preact.string(if subscriptionJson == "" { "Prepare Browser" } else { "✓ Browser Ready" })}
        </button>
      </section>

      <section className="manual-push-section">
        <h2> {Preact.string("Step 2: Register with Push Server")} </h2>
        <p> {Preact.string("Click below to link your browser with the push server and receive your unique webhook URL.")} </p>
        
        {switch error {
        | Some(msg) => <div className="error-message"> {Preact.string(msg)} </div>
        | None => Preact.null
        }}

        <button 
          className="button-primary" 
          onClick={_ => { let _ = handleRegister() }} 
          disabled={isRegistering || subscriptionJson == "" || userId == "" || serverGeneratedId->Option.isSome}
        >
          {Preact.string(switch (isRegistering, serverGeneratedId) {
          | (true, _) => "Registering..."
          | (_, Some(_)) => "✓ Registered with Push Server"
          | _ => "Get Webhook URL"
          })}
        </button>
      </section>

      {switch serverGeneratedId {
      | None => Preact.null
      | Some(sid) => 
        <section className="manual-push-section">
          <h2> {Preact.string("Step 3: Create Webhook on Misskey")} </h2>
          <p> {Preact.string("Finally, go to your Misskey settings and create a new webhook with these EXACT details:")} </p>
          <div className="manual-push-details">
            <div className="detail-item">
              <strong> {Preact.string("Name: ")} </strong>
              <span> {Preact.string("kaguya-manual")} </span>
            </div>
            <div className="detail-item">
              <strong> {Preact.string("URL: ")} </strong>
              <code> {Preact.string(PushNotificationStore.pushServerUrl ++ "/webhook/" ++ sid)} </code>
              <button onClick={_ => copyToClipboard(PushNotificationStore.pushServerUrl ++ "/webhook/" ++ sid)}> {Preact.string("Copy")} </button>
            </div>
            <div className="detail-item">
              <strong> {Preact.string("Secret: ")} </strong>
              <code> {Preact.string(webhookSecret)} </code>
              <button onClick={_ => copyToClipboard(webhookSecret)}> {Preact.string("Copy")} </button>
            </div>
            <div className="detail-item">
              <strong> {Preact.string("Events: ")} </strong>
              <span> {Preact.string("mention, reply, renote, reaction, follow, receiveFollowRequest, pollEnded")} </span>
            </div>
          </div>
          <p className="success-message" style={Style.make(~marginTop="20px", ())}> 
            {Preact.string("✓ You're all set! Once you create the webhook on Misskey, notifications will start appearing.")} 
          </p>
        </section>
      }}

      <div style={Style.make(~marginTop="40px", ~opacity="0.5", ~fontSize="12px", ())}>
        <Wouter.Link href="/"> {Preact.string("← Back to Home")} </Wouter.Link>
      </div>
    </div>
  </Layout>
}
