// SPDX-License-Identifier: MPL-2.0
// NotificationStore.res - Notification state management using Preact Signals

// ============================================================
// State
// ============================================================

let notifications: PreactSignals.signal<array<NotificationView.t>> = PreactSignals.make([])
let unreadCount: PreactSignals.signal<int> = PreactSignals.make(0)

// Subscription reference
let subscriptionRef: ref<option<Misskey.Stream.subscription>> = ref(None)

// Max notifications to keep in memory
let maxNotifications = 100

// ============================================================
// Actions
// ============================================================

// Add a notification (from stream), prepends to front
let addNotification = (notif: NotificationView.t): unit => {
  let current = PreactSignals.value(notifications)
  let exists = current->Array.some(n => n.id == notif.id)
  if !exists {
    let updated = [notif]->Array.concat(current)
    let capped = if updated->Array.length > maxNotifications {
      updated->Array.slice(~start=0, ~end=maxNotifications)
    } else {
      updated
    }
    PreactSignals.batch(() => {
      PreactSignals.setValue(notifications, capped)
      PreactSignals.setValue(unreadCount, PreactSignals.value(unreadCount) + 1)
    })
  }
}

// Fetch existing notifications from REST API
let fetchExisting = async (client: Misskey.t): unit => {
  // Check if we have cached data from AppInitializer
  switch AppInitializer.getCachedNotifications() {
  | Some(cachedResult) => {
      Console.log("NotificationStore: Using cached notifications")
      switch cachedResult {
      | Ok(json) =>
        switch json->JSON.Decode.array {
        | Some(items) => {
            let decoded =
              items
              ->Array.filterMap(item => NotificationView.decode(item))
            if decoded->Array.length > 0 {
              PreactSignals.setValue(notifications, decoded)
            }
          }
        | None => Console.error("NotificationStore: Unexpected response format")
        }
      | Error(msg) => Console.error2("NotificationStore: Failed to fetch notifications:", msg)
      }
    }
  | None => {
      // No cache, fetch from API
      Console.log("NotificationStore: Fetching notifications from API")
      let params = Dict.make()
      params->Dict.set("limit", JSON.Encode.int(30))
      let result = await client->Misskey.request(
        "i/notifications",
        ~params=JSON.Encode.object(params),
        (),
      )
      switch result {
      | Ok(json) =>
        switch json->JSON.Decode.array {
        | Some(items) => {
            let decoded =
              items
              ->Array.filterMap(item => NotificationView.decode(item))
            if decoded->Array.length > 0 {
              PreactSignals.setValue(notifications, decoded)
            }
          }
        | None => Console.error("NotificationStore: Unexpected response format")
        }
      | Error(msg) => Console.error2("NotificationStore: Failed to fetch notifications:", msg)
      }
    }
  }
}

// Mark all as read
let markAllRead = (): unit => {
  PreactSignals.setValue(unreadCount, 0)
}

// Clear all notifications
let clear = (): unit => {
  PreactSignals.batch(() => {
    PreactSignals.setValue(notifications, [])
    PreactSignals.setValue(unreadCount, 0)
  })
}

// Subscribe to notification stream and fetch existing
let subscribe = (client: Misskey.t): unit => {
  switch subscriptionRef.contents {
  | Some(_) => ()
  | None => {
      Console.log("NotificationStore: Subscribing to notification stream...")
      try {
        let sub = client->Misskey.Stream.notifications(notifJson => {
          switch NotificationView.decode(notifJson) {
          | Some(notif) => addNotification(notif)
          | None =>
            Console.log2("NotificationStore: Failed to decode notification", notifJson)
          }
        })
        subscriptionRef := Some(sub)
        Console.log("NotificationStore: Subscribed")
      } catch {
      | exn => Console.error2("NotificationStore: Failed to subscribe", exn)
      }
      // Fetch existing notifications
      let _ = fetchExisting(client)
    }
  }
}

// Unsubscribe from notification stream
let unsubscribe = (): unit => {
  switch subscriptionRef.contents {
  | Some(sub) => {
      sub.dispose()
      subscriptionRef := None
      Console.log("NotificationStore: Unsubscribed")
    }
  | None => ()
  }
}
