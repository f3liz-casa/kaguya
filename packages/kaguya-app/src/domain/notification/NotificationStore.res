// SPDX-License-Identifier: MPL-2.0

let notifications: PreactSignals.signal<array<NotificationView.t>> = PreactSignals.make([])
let unreadCount: PreactSignals.signal<int> = PreactSignals.make(0)

// Subscription reference
let subscriptionRef: ref<option<Misskey.Stream.subscription>> = ref(None)

// Max notifications to keep in memory
let maxNotifications = 100

// Actions

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

let setInitial = (result: result<JSON.t, string>): unit => {
  switch result {
  | Ok(json) =>
    switch json->JSON.Decode.array {
    | Some(items) =>
      let decoded = items->Array.filterMap(NotificationView.decode)
      if decoded->Array.length > 0 {
        PreactSignals.setValue(notifications, decoded)
      }
    | None => ()
    }
  | Error(_) => ()
  }
}

// Fetch existing notifications from REST API
let fetchExisting = async (client: Misskey.t): unit => {
  // If we already have notifications, don't fetch again (unless we want to refresh)
  if PreactSignals.value(notifications)->Array.length > 0 {
    ()
  } else {
    let params = Dict.make()
    params->Dict.set("limit", JSON.Encode.int(30))
    let result = await client->Misskey.request(
      "i/notifications",
      ~params=JSON.Encode.object(params),
      (),
    )
    setInitial(result)
  }
}

// Mark all as read
let markAllRead = (): unit => {
  PreactSignals.setValue(unreadCount, 0)
}

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
      try {
        let sub = client->Misskey.Stream.notifications(notifJson => {
          switch NotificationView.decode(notifJson) {
          | Some(notif) => addNotification(notif)
          | None => ()
          }
        })
        subscriptionRef := Some(sub)
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
    }
  | None => ()
  }
}
