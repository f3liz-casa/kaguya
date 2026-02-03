// Unified Notifications module
// Provides both REST fetch and WebSocket subscribe with consistent API

open MisskeyJS_Common

module API_Bindings = MisskeyJS_API_Bindings
module Stream_Bindings = MisskeyJS_Stream_Bindings
module Client = MisskeyJS_Client

// Subscription handle for streaming (Main channel)
type subscription = {
  connection: Stream_Bindings.Main.t,
}

// ============================================================
// Fetch (REST) - One-time poll, returns array
// ============================================================

type fetchParams = {
  limit?: int,
  sinceId?: id,
  untilId?: id,
  markAsRead?: bool,
  includeTypes?: array<notificationType>,
  excludeTypes?: array<notificationType>,
}

// Internal: Convert notification type to string
let notificationTypeToString = (nt: notificationType): string =>
  switch nt {
  | #note => "note"
  | #follow => "follow"
  | #mention => "mention"
  | #reply => "reply"
  | #renote => "renote"
  | #quote => "quote"
  | #reaction => "reaction"
  | #pollEnded => "pollEnded"
  | #scheduledNotePosted => "scheduledNotePosted"
  | #scheduledNotePostFailed => "scheduledNotePostFailed"
  | #receiveFollowRequest => "receiveFollowRequest"
  | #followRequestAccepted => "followRequestAccepted"
  | #app => "app"
  | #roleAssigned => "roleAssigned"
  | #chatRoomInvitationReceived => "chatRoomInvitationReceived"
  | #achievementEarned => "achievementEarned"
  | #exportCompleted => "exportCompleted"
  | #test => "test"
  | #login => "login"
  | #createToken => "createToken"
  }

// Internal: Encode fetch params to JSON
let encodeFetchParams = (params: fetchParams): JSON.t => {
  let obj = Dict.make()
  
  params.limit->Option.forEach(v => obj->Dict.set("limit", JSON.Encode.int(v)))
  params.sinceId->Option.forEach(v => obj->Dict.set("sinceId", JSON.Encode.string(v)))
  params.untilId->Option.forEach(v => obj->Dict.set("untilId", JSON.Encode.string(v)))
  params.markAsRead->Option.forEach(v => obj->Dict.set("markAsRead", JSON.Encode.bool(v)))
  params.includeTypes->Option.forEach(types => {
    let arr = types->Array.map(t => JSON.Encode.string(notificationTypeToString(t)))
    obj->Dict.set("includeTypes", JSON.Encode.array(arr))
  })
  params.excludeTypes->Option.forEach(types => {
    let arr = types->Array.map(t => JSON.Encode.string(notificationTypeToString(t)))
    obj->Dict.set("excludeTypes", JSON.Encode.array(arr))
  })
  
  JSON.Encode.object(obj)
}

// Fetch notifications (REST)
let fetch = async (
  client: Client.t,
  ~params: fetchParams={},
  (),
): result<array<JSON.t>, [> #APIError(apiError) | #UnknownError(exn)]> => {
  let jsonParams = encodeFetchParams(params)
  
  try {
    let result = await Client.request(
      client,
      ~endpoint="i/notifications",
      ~params=jsonParams,
    )
    Ok(result->Obj.magic)
  } catch {
  | error =>
    switch isAPIError(error) {
    | Some(apiErr) => Error(#APIError(apiErr))
    | None => Error(#UnknownError(error))
    }
  }
}

// Mark all notifications as read
let markAllAsRead = async (
  client: Client.t,
): result<unit, [> #APIError(apiError) | #UnknownError(exn)]> => {
  try {
    let _ = await Client.request(
      client,
      ~endpoint="notifications/mark-all-as-read",
    )
    Ok()
  } catch {
  | error =>
    switch isAPIError(error) {
    | Some(apiErr) => Error(#APIError(apiErr))
    | None => Error(#UnknownError(error))
    }
  }
}

// ============================================================
// Subscribe (Stream) - Real-time updates via Main channel
// ============================================================

// Subscribe to notifications (Stream)
let subscribe = (client: Client.t): subscription => {
  let stream = Client.streamClient(client)
  let connection = Stream_Bindings.useChannel(
    ~stream,
    ~channel="main",
    (),
  )->Obj.magic
  
  {connection: connection}
}

// Event handlers (all pipeable, return subscription for chaining)

let onNotification = (sub: subscription, callback: JSON.t => unit): subscription => {
  Stream_Bindings.Main.onNotification(sub.connection, callback)
  sub
}

let onMention = (sub: subscription, callback: JSON.t => unit): subscription => {
  Stream_Bindings.Main.onMention(sub.connection, callback)
  sub
}

let onReply = (sub: subscription, callback: JSON.t => unit): subscription => {
  Stream_Bindings.Main.onReply(sub.connection, callback)
  sub
}

let onRenote = (sub: subscription, callback: JSON.t => unit): subscription => {
  Stream_Bindings.Main.onRenote(sub.connection, callback)
  sub
}

let onFollow = (sub: subscription, callback: JSON.t => unit): subscription => {
  Stream_Bindings.Main.onFollow(sub.connection, callback)
  sub
}

let onFollowed = (sub: subscription, callback: JSON.t => unit): subscription => {
  Stream_Bindings.Main.onFollowed(sub.connection, callback)
  sub
}

let onUnfollow = (sub: subscription, callback: JSON.t => unit): subscription => {
  Stream_Bindings.Main.onUnfollow(sub.connection, callback)
  sub
}

let onMeUpdated = (sub: subscription, callback: JSON.t => unit): subscription => {
  Stream_Bindings.Main.onMeUpdated(sub.connection, callback)
  sub
}

let onReadAllNotifications = (sub: subscription, callback: unit => unit): subscription => {
  Stream_Bindings.Main.onReadAllNotifications(sub.connection, callback)
  sub
}

// Dispose subscription
let dispose = (sub: subscription): unit => {
  Stream_Bindings.dispose(sub.connection)
}
