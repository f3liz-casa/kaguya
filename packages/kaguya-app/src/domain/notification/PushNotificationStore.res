// SPDX-License-Identifier: MPL-2.0
//
// Uses an external push-server (push-server.f3liz.casa) that receives
// Misskey webhooks and delivers Web Push notifications.
//
// Flow:
//   1. Browser subscribes to push via PushManager (push-server's VAPID key)
//   2. Client creates a Misskey webhook (i/webhooks/create) — token stays in browser
//   3. Client registers with push-server (/register) — no token sent
//   4. Misskey sends webhooks → push-server → browser push

// Configuration

let pushServerUrl = "https://push-server.f3liz.casa"
let pushServerVapidKey = "BL93HHKUfvDXsannCPVrQ0ckABtvNTvYZl4W6-Zvxx0LW_MupHtronpz65HHHJVxnGHoswAV3JSNlkHSUCOcbPI" // Set after VAPID key generation on server

type pushState =
  | NotSupported
  | PermissionDenied
  | Unsubscribed
  | Subscribing
  | Subscribed
  | Error(string)

// Signals

let state: PreactSignals.signal<pushState> = PreactSignals.make(NotSupported)

// localStorage keys
let storageKeyPrefix = "kaguya:pushEnabled:"
let webhookIdPrefix = "kaguya:webhookId:"
let serverUserIdPrefix = "kaguya:serverUserId:"
let webhookSecretPrefix = "kaguya:webhookSecret:"

@val @scope("localStorage")
external getItem: string => Nullable.t<string> = "getItem"

@val @scope("localStorage")
external setItem: (string, string) => unit = "setItem"

@val @scope("localStorage")
external removeItem: string => unit = "removeItem"

// crypto.randomUUID()
@val @scope("crypto")
external randomUUID: unit => string = "randomUUID"

// fetch for push-server API (not Misskey)
@val external fetch: (string, {..}) => promise<{..}> = "fetch"

// Core Logic

/// Initialize push state — call on app start or login.
let init = (): unit => {
  if !ServiceWorkerAPI.isSupported() || !ServiceWorkerAPI.isNotificationSupported() {
    PreactSignals.setValue(state, NotSupported)
  } else if pushServerVapidKey == "" {
    PreactSignals.setValue(state, NotSupported)
  } else {
    switch ServiceWorkerAPI.permission {
    | #denied => PreactSignals.setValue(state, PermissionDenied)
    | _ => PreactSignals.setValue(state, Unsubscribed)
    }
  }
}

/// Subscribe to push notifications via push-server.
/// 1. Request notification permission
/// 2. Register service worker + subscribe to push (push-server's VAPID key)
/// 3. Create Misskey webhook (check if already exists)
/// 4. Register with push-server (webhook secret + push subscription, no token)
let subscribe = async (client: Misskey.t, accountId: string): result<unit, string> => {
  if !ServiceWorkerAPI.isSupported() || !ServiceWorkerAPI.isNotificationSupported() {
    Error("Push notifications not supported in this browser")
  } else if pushServerVapidKey == "" {
    Error("Push server VAPID key not configured")
  } else {
    PreactSignals.setValue(state, Subscribing)
    try {
      // 1. Request notification permission
      let perm = await ServiceWorkerAPI.requestPermission()
      if perm == #denied {
        PreactSignals.setValue(state, PermissionDenied)
        Error("Notification permission denied")
      } else {
        // 2. Register service worker and subscribe to push
        let registration = await ServiceWorkerAPI.register("/sw.js")
        let pm = ServiceWorkerAPI.pushManager(registration)
        
        let existingSub = await ServiceWorkerAPI.getSubscription(pm)
        let subscription = switch existingSub->Nullable.toOption {
        | Some(sub) => sub
        | None => {
            let opts = ServiceWorkerAPI.makeSubscribeOptions(pushServerVapidKey)
            await ServiceWorkerAPI.subscribe(pm, opts)
          }
        }
        let subJSON = ServiceWorkerAPI.toJSON(subscription)

        // 3. Create or find webhook on Misskey (token stays in browser)
        let webhookSecret = randomUUID()
        let origin = Misskey.origin(client)

        let userResult = await Misskey.currentUser(client)
        switch userResult {
        | Error(e) => {
            PreactSignals.setValue(state, Error(e))
            Error("Failed to get current user: " ++ e)
          }
        | Ok(userJson) => {
            let userId = switch userJson->JSON.Decode.object {
            | Some(obj) => obj->Dict.get("id")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
            | None => ""
            }

            if userId == "" {
              PreactSignals.setValue(state, Error("No user ID"))
              Error("Could not determine user ID")
            } else {
              let regBody = {
                "misskey_origin": origin,
                "webhook_user_id": userId,
                "webhook_secret": webhookSecret,
                "push_subscription": subJSON->Obj.magic,
                "notification_preference": "quiet",
                "delay_minutes": 1,
              }

              let regResponse = await fetch(
                pushServerUrl ++ "/register",
                {
                  "method": "POST",
                  "headers": {"Content-Type": "application/json"},
                  "body": JSON.stringifyAny(regBody)->Option.getOr("{}"),
                },
              )

              if (regResponse["ok"]: bool) {
                let json = await %raw(`regResponse.json()`)
                let serverId = (json["id"]: string)

                // 4. Create webhook on Misskey (token stays in browser)
                let webhookResult = await Misskey.Webhooks.create(
                  client,
                  ~name="kaguya push",
                  ~url=pushServerUrl ++ "/webhook/" ++ serverId,
                  ~secret=webhookSecret,
                  ~on=[
                    "mention",
                    "reply",
                    "renote",
                    "reaction",
                    "follow",
                    "receiveFollowRequest",
                    "pollEnded",
                  ],
                  (),
                )

                switch webhookResult {
                | Error(e) => {
                    // Try to clean up the push-server registration if possible
                    let _ = fetch(
                      pushServerUrl ++ "/unregister",
                      {
                        "method": "DELETE",
                        "headers": {
                          "Content-Type": "application/json",
                          "X-Misskey-Hook-Secret": webhookSecret,
                        },
                        "body": JSON.stringifyAny({"id": serverId})->Option.getOr("{}"),
                      },
                    )
                    PreactSignals.setValue(state, Error(e))
                    Error("Failed to create Misskey webhook: " ++ e)
                  }
                | Ok(webhook) => {
                    setItem(storageKeyPrefix ++ accountId, "true")
                    setItem(webhookIdPrefix ++ accountId, webhook.id)
                    setItem(serverUserIdPrefix ++ accountId, serverId)
                    setItem(webhookSecretPrefix ++ accountId, webhookSecret)
                    PreactSignals.setValue(state, Subscribed)
                    Ok()
                  }
                }
              } else {
                PreactSignals.setValue(state, Error("Push server registration failed"))
                Error("Push server returned error")
              }
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
        Error("Push subscription failed: " ++ msg)
      }
    }
  }
}

/// Unsubscribe from push notifications.
let unsubscribe = async (client: Misskey.t, accountId: string): result<unit, string> => {
  try {
    // 1. Delete Misskey webhook
    let webhookId = getItem(webhookIdPrefix ++ accountId)->Nullable.toOption
    switch webhookId {
    | Some(id) => {
        let _ = await Misskey.Webhooks.delete(client, ~webhookId=id)
      }
    | None => ()
    }

    // 2. Unregister from push-server
    let serverId = getItem(serverUserIdPrefix ++ accountId)->Nullable.toOption
    let webhookSecret = getItem(webhookSecretPrefix ++ accountId)->Nullable.toOption

    switch (serverId, webhookSecret) {
    | (Some(id), Some(secret)) => {
        let _ = await fetch(
          pushServerUrl ++ "/unregister",
          {
            "method": "DELETE",
            "headers": {
              "Content-Type": "application/json",
              "X-Misskey-Hook-Secret": secret,
            },
            "body": JSON.stringifyAny({"id": id})->Option.getOr("{}"),
          },
        )
      }
    | _ => ()
    }

    // 3. Unsubscribe browser push
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

    // 4. Clear local state
    removeItem(storageKeyPrefix ++ accountId)
    removeItem(webhookIdPrefix ++ accountId)
    removeItem(serverUserIdPrefix ++ accountId)
    removeItem(webhookSecretPrefix ++ accountId)
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

/// Check if push is enabled for the given account.
let isEnabledForAccount = (accountId: string): bool => {
  switch getItem(storageKeyPrefix ++ accountId)->Nullable.toOption {
  | Some("true") => true
  | _ => false
  }
}

/// Restore push state on login — checks existing subscription.
/// If push is enabled but no subscription is found, it attempts to re-register
/// if browser permissions are already granted.
let restore = async (client: Misskey.t, accountId: string): unit => {
  init()
  if isEnabledForAccount(accountId) && ServiceWorkerAPI.isSupported() {
    try {
      let registration = await ServiceWorkerAPI.register("/sw.js")
      let pm = ServiceWorkerAPI.pushManager(registration)
      let existingSub = await ServiceWorkerAPI.getSubscription(pm)
      let webhookId = getItem(webhookIdPrefix ++ accountId)->Nullable.toOption

      switch (existingSub->Nullable.toOption, webhookId) {
      | (Some(_), Some(_)) => PreactSignals.setValue(state, Subscribed)
      | (Some(_), None)
      | (None, _) =>
        // If enabled in storage but mismatch/missing sub/webhook, try auto-repair
        // ONLY if permission is already granted (to avoid unexpected popups)
        if ServiceWorkerAPI.permission == #granted {
          let _ = await subscribe(client, accountId)
        } else {
          PreactSignals.setValue(state, Unsubscribed)
        }
      }
    } catch {
    | _ => PreactSignals.setValue(state, Unsubscribed)
    }
  }
}
