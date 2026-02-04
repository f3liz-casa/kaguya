// Unified Timeline module
// Provides both REST fetch and WebSocket subscribe with consistent API

open MisskeyJS_Common

// Import generated API modules (not currently used - using Client.request instead)
// module GeneratedNotes = Generated.Notes
// module GeneratedAntennas = Generated.Antennas
// module GeneratedChannels = Generated.Channels
// module GeneratedLists = Generated.Lists

module Stream_Bindings = NativeStreamBindings
module Client = MisskeyJS_Client

// Timeline types
type timelineType = [
  | #home
  | #local
  | #global
  | #hybrid
  | #antenna(id)
  | #userList(id)
  | #channel(id)
]

// Subscription handle for streaming
type subscription = {
  connection: Stream_Bindings.Timeline.t,
}

// ============================================================
// Fetch (REST) - One-time poll, returns array
// ============================================================

type fetchParams = {
  // Pagination
  limit?: int,
  sinceId?: id,
  untilId?: id,
  sinceDate?: int,
  untilDate?: int,
  // Filters (common)
  withRenotes?: bool,
  withFiles?: bool,
  // Local/Hybrid only
  withReplies?: bool,
  // Local only
  excludeNsfw?: bool,
  // Home only
  includeMyRenotes?: bool,
  includeRenotedMyNotes?: bool,
  includeLocalRenotes?: bool,
}

// Internal: Get API endpoint for timeline type
let getEndpoint = (type_: timelineType): string => {
  switch type_ {
  | #home => "notes/timeline"
  | #local => "notes/local-timeline"
  | #global => "notes/global-timeline"
  | #hybrid => "notes/hybrid-timeline"
  | #antenna(_) => "antennas/notes"
  | #userList(_) => "notes/user-list-timeline"
  | #channel(_) => "channels/timeline"
  }
}

// Internal: Convert params to JSON for API request
let encodeFetchParams = (type_: timelineType, params: fetchParams): JSON.t => {
  let obj = Dict.make()

  // Add ID parameter for custom timelines
  switch type_ {
  | #antenna(id) => obj->Dict.set("antennaId", JSON.Encode.string(id))
  | #userList(id) => obj->Dict.set("listId", JSON.Encode.string(id))
  | #channel(id) => obj->Dict.set("channelId", JSON.Encode.string(id))
  | _ => ()
  }

  params.limit->Option.forEach(v => obj->Dict.set("limit", JSON.Encode.int(v)))
  params.sinceId->Option.forEach(v => obj->Dict.set("sinceId", JSON.Encode.string(v)))
  params.untilId->Option.forEach(v => obj->Dict.set("untilId", JSON.Encode.string(v)))
  params.sinceDate->Option.forEach(v => obj->Dict.set("sinceDate", JSON.Encode.int(v)))
  params.untilDate->Option.forEach(v => obj->Dict.set("untilDate", JSON.Encode.int(v)))
  params.withRenotes->Option.forEach(v => obj->Dict.set("withRenotes", JSON.Encode.bool(v)))
  params.withFiles->Option.forEach(v => obj->Dict.set("withFiles", JSON.Encode.bool(v)))
  params.withReplies->Option.forEach(v => obj->Dict.set("withReplies", JSON.Encode.bool(v)))
  params.excludeNsfw->Option.forEach(v => obj->Dict.set("excludeNsfw", JSON.Encode.bool(v)))
  params.includeMyRenotes->Option.forEach(v =>
    obj->Dict.set("includeMyRenotes", JSON.Encode.bool(v))
  )
  params.includeRenotedMyNotes->Option.forEach(v =>
    obj->Dict.set("includeRenotedMyNotes", JSON.Encode.bool(v))
  )
  params.includeLocalRenotes->Option.forEach(v =>
    obj->Dict.set("includeLocalRenotes", JSON.Encode.bool(v))
  )

  JSON.Encode.object(obj)
}

// Fetch timeline (REST)
let fetch = async (client: Client.t, ~type_: timelineType, ~params: fetchParams={}, ()): result<
  array<JSON.t>,
  [> #APIError(apiError) | #UnknownError(exn)],
> => {
  let endpoint = getEndpoint(type_)
  let jsonParams = encodeFetchParams(type_, params)

  try {
    let result = await Client.request(client, ~endpoint, ~params=jsonParams)
    // Result is array<JSON.t>
    Ok(result->Obj.magic)
  } catch {
  | error =>
    switch isAPIError(error) {
    | Some(apiErr) => Error(#APIError(apiErr))
    | None => Error(#UnknownError(error))
    }
  }
}

// ============================================================
// Subscribe (Stream) - Real-time updates
// ============================================================

type subscribeParams = {
  withRenotes?: bool,
  withFiles?: bool,
  withReplies?: bool,
}

// Internal: Get channel name for timeline type
let getChannelName = (type_: timelineType): string => {
  switch type_ {
  | #home => "homeTimeline"
  | #local => "localTimeline"
  | #global => "globalTimeline"
  | #hybrid => "hybridTimeline"
  | #antenna(_) => "antenna"
  | #userList(_) => "userList"
  | #channel(_) => "channel"
  }
}

// Internal: Encode subscribe params to JSON
let encodeSubscribeParams = (type_: timelineType, params: subscribeParams): JSON.t => {
  let obj = Dict.make()

  // Add ID parameter for custom timelines
  switch type_ {
  | #antenna(id) => obj->Dict.set("antennaId", JSON.Encode.string(id))
  | #userList(id) => obj->Dict.set("listId", JSON.Encode.string(id))
  | #channel(id) => obj->Dict.set("channelId", JSON.Encode.string(id))
  | _ => ()
  }

  params.withRenotes->Option.forEach(v => obj->Dict.set("withRenotes", JSON.Encode.bool(v)))
  params.withFiles->Option.forEach(v => obj->Dict.set("withFiles", JSON.Encode.bool(v)))
  params.withReplies->Option.forEach(v => obj->Dict.set("withReplies", JSON.Encode.bool(v)))

  JSON.Encode.object(obj)
}

// Subscribe to timeline (Stream)
let subscribe = (
  client: Client.t,
  ~type_: timelineType,
  ~params: subscribeParams={},
  (),
): subscription => {
  let stream = Client.streamClient(client)
  let channelName = getChannelName(type_)
  let jsonParams = encodeSubscribeParams(type_, params)

  let connection =
    Stream_Bindings.useChannel(~stream, ~channel=channelName, ~params=jsonParams, ())->Obj.magic

  {connection: connection}
}

// Attach note handler (pipeable, returns subscription for chaining)
let onNote = (sub: subscription, callback: JSON.t => unit): subscription => {
  Stream_Bindings.Timeline.onNote(sub.connection, callback)
  sub
}

// Dispose subscription
let dispose = (sub: subscription): unit => {
  Stream_Bindings.dispose(sub.connection)
}
