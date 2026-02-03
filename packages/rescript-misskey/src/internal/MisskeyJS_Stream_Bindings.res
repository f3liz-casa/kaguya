// Low-level bindings to misskey-js Stream and Connection classes
// This module provides direct FFI bindings with minimal abstraction

open MisskeyJS_Common

// Stream state
type streamState = [#initializing | #reconnecting | #connected]

// User authentication
type streamUser = {token: string}

// Stream options
type streamOptions = {
  @as("WebSocket") webSocket?: Blob.t, // WebSocket constructor
  binaryType?: [#blob | #arraybuffer],
}

// Stream class binding
type stream

@module("misskey-js") @new
external makeStream: (string, Nullable.t<streamUser>, ~options: streamOptions=?) => stream =
  "Stream"

let make = (~origin, ~user=?, ~options=?, ()) => {
  makeStream(origin, user->Nullable.fromOption, ~options?)
}

@get external state: stream => streamState = "state"

// Event listeners
@send
external onConnected: (stream, @as("_connected_") _, unit => unit) => unit = "on"

@send
external onDisconnected: (stream, @as("_disconnected_") _, unit => unit) => unit = "on"

// Low-level send methods
@send external sendTyped: (stream, string, JSON.t) => unit = "send"
@send external sendRaw: (stream, JSON.t) => unit = "send"

// Connection management
@send external ping: stream => unit = "ping"
@send external heartbeat: stream => unit = "heartbeat"
@send external close: stream => unit = "close"

// Channel connection
type connection<'events, 'receives>

// useChannel binding - polymorphic based on channel type
@send
external useChannelWithParams: (
  stream,
  string,
  JSON.t,
  ~name: string=?,
) => connection<'events, 'receives> = "useChannel"

@send
external useChannelWithoutParams: (
  stream,
  string,
  ~name: string=?,
) => connection<'events, 'receives> = "useChannel"

let useChannel = (~stream, ~channel, ~params=?, ~name=?, ()) => {
  switch params {
  | Some(p) => useChannelWithParams(stream, channel, p, ~name?)
  | None => useChannelWithoutParams(stream, channel, ~name?)
  }
}

// Connection class methods
@get external channelId: connection<'events, 'receives> => string = "channel"
@get external connectionId: connection<'events, 'receives> => string = "id"
@get external connectionName: connection<'events, 'receives> => option<string> = "name"
@get external inCount: connection<'events, 'receives> => int = "inCount"
@get external outCount: connection<'events, 'receives> => int = "outCount"

@send external dispose: connection<'events, 'receives> => unit = "dispose"

// Generic event listener
@send
external on: (connection<'events, 'receives>, string, JSON.t => unit) => unit = "on"

// Generic send method for channel communication
@send
external send: (connection<'events, 'receives>, string, JSON.t) => unit = "send"

// Typed event listeners for specific channel events
// These will be used in the high-level wrapper

module Main = {
  type events
  type receives = unit

  type t = connection<events, receives>

  @send external onNotification: (t, @as("notification") _, JSON.t => unit) => unit = "on"
  @send external onMention: (t, @as("mention") _, JSON.t => unit) => unit = "on"
  @send external onReply: (t, @as("reply") _, JSON.t => unit) => unit = "on"
  @send external onRenote: (t, @as("renote") _, JSON.t => unit) => unit = "on"
  @send external onFollow: (t, @as("follow") _, JSON.t => unit) => unit = "on"
  @send external onFollowed: (t, @as("followed") _, JSON.t => unit) => unit = "on"
  @send external onUnfollow: (t, @as("unfollow") _, JSON.t => unit) => unit = "on"
  @send external onMeUpdated: (t, @as("meUpdated") _, JSON.t => unit) => unit = "on"
  @send
  external onReadAllNotifications: (t, @as("readAllNotifications") _, unit => unit) => unit = "on"
}

module Timeline = {
  type events
  type receives = unit

  type t = connection<events, receives>

  @send external onNote: (t, @as("note") _, JSON.t => unit) => unit = "on"
}

module Drive = {
  type events
  type receives = unit

  type t = connection<events, receives>

  @send external onFileCreated: (t, @as("fileCreated") _, JSON.t => unit) => unit = "on"
  @send external onFileDeleted: (t, @as("fileDeleted") _, string => unit) => unit = "on"
  @send external onFileUpdated: (t, @as("fileUpdated") _, JSON.t => unit) => unit = "on"
  @send external onFolderCreated: (t, @as("folderCreated") _, JSON.t => unit) => unit = "on"
  @send external onFolderDeleted: (t, @as("folderDeleted") _, string => unit) => unit = "on"
  @send external onFolderUpdated: (t, @as("folderUpdated") _, JSON.t => unit) => unit = "on"
}

module ServerStats = {
  type events
  type receives

  type t = connection<events, receives>

  @send external onStats: (t, @as("stats") _, JSON.t => unit) => unit = "on"
  @send external onStatsLog: (t, @as("statsLog") _, JSON.t => unit) => unit = "on"

  type requestLogParams = {\"id": string, \"length": int}

  @send
  external requestLog: (t, @as("requestLog") _, requestLogParams) => unit = "send"
}
