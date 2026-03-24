// SPDX-License-Identifier: MPL-2.0
//
// Native Misskey push notifications via AiScript + sw/register.
//
// Because Misskey blocks sw/register from third-party OAuth tokens,
// we generate an AiScript that the user runs in Misskey's Scratchpad.
// The script subscribes the browser and calls sw/register on the user's
// behalf using their full Misskey session.
//
// Flow:
//   1. Fetch instance VAPID key from /api/meta (swPublickey)
//   2. Subscribe browser to push using that VAPID key
//   3. Generate AiScript containing the endpoint/keys
//   4. User copies AiScript → runs in Misskey Scratchpad → sw/register called
//   5. User confirms → state becomes Subscribed

type pushState =
  | NotSupported
  | PermissionDenied
  | Unsubscribed
  | GeneratingScript
  | AwaitingScript(string) // holds the generated AiScript
  | Subscribed
  | Error(string)

let state: PreactSignals.signal<pushState> = PreactSignals.make(NotSupported)

let storageKeyPrefix = "kaguya:nativePushEnabled:"
let endpointPrefix = "kaguya:nativePushEndpoint:"

@val @scope("localStorage")
external getItem: string => Nullable.t<string> = "getItem"

@val @scope("localStorage")
external setItem: (string, string) => unit = "setItem"

@val @scope("localStorage")
external removeItem: string => unit = "removeItem"

let init = (): unit => {
  if !ServiceWorkerAPI.isSupported() || !ServiceWorkerAPI.isNotificationSupported() {
    PreactSignals.setValue(state, NotSupported)
  } else {
    switch ServiceWorkerAPI.permission {
    | #denied => PreactSignals.setValue(state, PermissionDenied)
    | _ => PreactSignals.setValue(state, Unsubscribed)
    }
  }
}

// Build the AiScript that calls sw/register on the Misskey instance
let buildAiScript = (
  ~expectedUsername: string,
  ~misskeyOrigin: string,
  ~endpoint: string,
  ~auth: string,
  ~p256dh: string,
): string => {
  `/// @ 0.18.0
// Generated for @${expectedUsername} on ${misskeyOrigin}

if ((USER_USERNAME != '${expectedUsername}') || ((SERVER_URL != '${misskeyOrigin}/') && (SERVER_URL != '${misskeyOrigin}'))) {
  Mk:dialog('Validation Failed', 'Account/Host mismatch.', 'error')
  Core:abort()
}

let response = Mk:api('sw/register', {
  endpoint: '${endpoint}',
  auth: '${auth}',
  publickey: '${p256dh}',
})

if (Core:type(response) == 'error') {
  Mk:dialog('Registration Failed', Core:to_str(response.info), 'error')
} else {
  Mk:dialog('Success!', 'Push notifications enabled. You can close this window.', 'success')
}`
}

let generateScript = async (client: Misskey.t, accountId: string): result<unit, string> => {
  if !ServiceWorkerAPI.isSupported() || !ServiceWorkerAPI.isNotificationSupported() {
    Error("Push notifications not supported in this browser")
  } else {
    PreactSignals.setValue(state, GeneratingScript)
    try {
      // 1. Fetch instance VAPID key
      let metaResult = await Misskey.Meta.get(client)
      switch metaResult {
      | Error(e) => {
          PreactSignals.setValue(state, Error(e))
          Error("Failed to fetch instance meta: " ++ e)
        }
      | Ok(meta) =>
        switch meta.swPublickey {
        | None => {
            PreactSignals.setValue(state, NotSupported)
            Error("Push notifications not enabled on this instance")
          }
        | Some(vapidKey) => {
            // 2. Request notification permission
            let perm = await ServiceWorkerAPI.requestPermission()
            if perm == #denied {
              PreactSignals.setValue(state, PermissionDenied)
              Error("Notification permission denied")
            } else {
              // 3. Subscribe browser to push using instance VAPID key
              let registration = await ServiceWorkerAPI.register("/sw.js")
              let pm = ServiceWorkerAPI.pushManager(registration)

              let existingSub = await ServiceWorkerAPI.getSubscription(pm)
              let subscription = switch existingSub->Nullable.toOption {
              | Some(sub) => sub
              | None => {
                  let opts = ServiceWorkerAPI.makeSubscribeOptions(vapidKey)
                  await ServiceWorkerAPI.subscribe(pm, opts)
                }
              }

              let endpoint = ServiceWorkerAPI.endpoint(subscription)
              let p256dh = ServiceWorkerAPI.encodeKeyBase64Url(subscription->ServiceWorkerAPI.getKey("p256dh"))
              let auth = ServiceWorkerAPI.encodeKeyBase64Url(subscription->ServiceWorkerAPI.getKey("auth"))

              // 4. Get username for AiScript validation
              let userResult = await Misskey.currentUser(client)
              let username = switch userResult {
              | Ok(userJson) =>
                userJson
                ->JSON.Decode.object
                ->Option.flatMap(obj => obj->Dict.get("username"))
                ->Option.flatMap(JSON.Decode.string)
                ->Option.getOr("unknown")
              | Error(_) => "unknown"
              }

              let misskeyOrigin = Misskey.origin(client)
              let script = buildAiScript(
                ~expectedUsername=username,
                ~misskeyOrigin,
                ~endpoint,
                ~auth,
                ~p256dh,
              )

              // Store endpoint so we can unsubscribe later
              setItem(endpointPrefix ++ accountId, endpoint)

              PreactSignals.setValue(state, AwaitingScript(script))
              Ok()
            }
          }
        }
      }
    } catch {
    | exn => {
        let msg = switch exn->JsExn.fromException {
        | Some(jsExn) => JsExn.message(jsExn)->Option.getOr("Unknown error")
        | None => "Unknown error"
        }
        PreactSignals.setValue(state, Error(msg))
        Error("Script generation failed: " ++ msg)
      }
    }
  }
}

// Called after user confirms they ran the AiScript successfully
let confirmSubscribed = (accountId: string): unit => {
  setItem(storageKeyPrefix ++ accountId, "true")
  PreactSignals.setValue(state, Subscribed)
}

let unsubscribe = async (_client: Misskey.t, accountId: string): result<unit, string> => {
  // We can't call sw/unregister either (same token restriction),
  // so just unsubscribe the browser push and clear local state.
  // The Misskey instance will eventually clean up the dead endpoint.
  try {
    if ServiceWorkerAPI.isSupported() {
      let registration = await ServiceWorkerAPI.register("/sw.js")
      let pm = ServiceWorkerAPI.pushManager(registration)
      let existingSub = await ServiceWorkerAPI.getSubscription(pm)
      switch existingSub->Nullable.toOption {
      | Some(sub) => {
          let _ = await ServiceWorkerAPI.unsubscribe(sub)
        }
      | None => ()
      }
    }
    removeItem(storageKeyPrefix ++ accountId)
    removeItem(endpointPrefix ++ accountId)
    PreactSignals.setValue(state, Unsubscribed)
    Ok()
  } catch {
  | exn => {
      let msg = switch exn->JsExn.fromException {
      | Some(jsExn) => JsExn.message(jsExn)->Option.getOr("Unknown error")
      | None => "Unknown error"
      }
      Error("Push unsubscribe failed: " ++ msg)
    }
  }
}

let isEnabledForAccount = (accountId: string): bool => {
  switch getItem(storageKeyPrefix ++ accountId)->Nullable.toOption {
  | Some("true") => true
  | _ => false
  }
}

let restore = async (client: Misskey.t, accountId: string): unit => {
  init()
  if isEnabledForAccount(accountId) && ServiceWorkerAPI.isSupported() {
    try {
      let registration = await ServiceWorkerAPI.register("/sw.js")
      let pm = ServiceWorkerAPI.pushManager(registration)
      let existingSub = await ServiceWorkerAPI.getSubscription(pm)
      switch existingSub->Nullable.toOption {
      | Some(_) => PreactSignals.setValue(state, Subscribed)
      | None =>
        // Subscription expired — need to re-run the AiScript flow
        removeItem(storageKeyPrefix ++ accountId)
        if ServiceWorkerAPI.permission == #granted {
          let _ = await generateScript(client, accountId)
        } else {
          PreactSignals.setValue(state, Unsubscribed)
        }
      }
    } catch {
    | _ => PreactSignals.setValue(state, Unsubscribed)
    }
  }
}
