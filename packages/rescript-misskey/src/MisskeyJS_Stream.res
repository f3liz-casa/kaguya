// Stream module - Less-common streaming channels
// Contains Drive and ServerStats channels
// For common streaming, use Timeline.subscribe() and Notifications.subscribe()

module Stream_Bindings = MisskeyJS_Stream_Bindings
module Client = MisskeyJS_Client

// ============================================================
// Drive Channel - File/folder events (rare)
// ============================================================

module Drive = {
  type subscription = {
    connection: Stream_Bindings.Drive.t,
  }
  
  // Subscribe to drive events
  let use = (client: Client.t): subscription => {
    let stream = Client.streamClient(client)
    let connection = Stream_Bindings.useChannel(
      ~stream,
      ~channel="drive",
      (),
    )->Obj.magic
    
    {connection: connection}
  }
  
  // Event handlers (all pipeable, return subscription for chaining)
  
  let onFileCreated = (sub: subscription, callback: JSON.t => unit): subscription => {
    Stream_Bindings.Drive.onFileCreated(sub.connection, callback)
    sub
  }
  
  let onFileDeleted = (sub: subscription, callback: string => unit): subscription => {
    Stream_Bindings.Drive.onFileDeleted(sub.connection, callback)
    sub
  }
  
  let onFileUpdated = (sub: subscription, callback: JSON.t => unit): subscription => {
    Stream_Bindings.Drive.onFileUpdated(sub.connection, callback)
    sub
  }
  
  let onFolderCreated = (sub: subscription, callback: JSON.t => unit): subscription => {
    Stream_Bindings.Drive.onFolderCreated(sub.connection, callback)
    sub
  }
  
  let onFolderDeleted = (sub: subscription, callback: string => unit): subscription => {
    Stream_Bindings.Drive.onFolderDeleted(sub.connection, callback)
    sub
  }
  
  let onFolderUpdated = (sub: subscription, callback: JSON.t => unit): subscription => {
    Stream_Bindings.Drive.onFolderUpdated(sub.connection, callback)
    sub
  }
  
  let dispose = (sub: subscription): unit => {
    Stream_Bindings.dispose(sub.connection)
  }
}

// ============================================================
// ServerStats Channel - Server statistics (admin, rare)
// ============================================================

module ServerStats = {
  type subscription = {
    connection: Stream_Bindings.ServerStats.t,
  }
  
  // Subscribe to server stats
  let use = (client: Client.t): subscription => {
    let stream = Client.streamClient(client)
    let connection = Stream_Bindings.useChannel(
      ~stream,
      ~channel="serverStats",
      (),
    )->Obj.magic
    
    {connection: connection}
  }
  
  // Event handlers (all pipeable, return subscription for chaining)
  
  let onStats = (sub: subscription, callback: JSON.t => unit): subscription => {
    Stream_Bindings.ServerStats.onStats(sub.connection, callback)
    sub
  }
  
  let onStatsLog = (sub: subscription, callback: JSON.t => unit): subscription => {
    Stream_Bindings.ServerStats.onStatsLog(sub.connection, callback)
    sub
  }
  
  // Request historical stats
  let requestLog = (sub: subscription, ~id: string, ~length: int): subscription => {
    Stream_Bindings.ServerStats.requestLog(sub.connection, {\"id": id, \"length": length})
    sub
  }
  
  let dispose = (sub: subscription): unit => {
    Stream_Bindings.dispose(sub.connection)
  }
}

// ============================================================
// Low-level stream access (for advanced use)
// ============================================================

// Re-export stream state type
type streamState = Stream_Bindings.streamState

// Get the stream state
let state = (client: Client.t): streamState => {
  Stream_Bindings.state(Client.streamClient(client))
}

// Ping the stream
let ping = (client: Client.t): unit => {
  Stream_Bindings.ping(Client.streamClient(client))
}

// Heartbeat
let heartbeat = (client: Client.t): unit => {
  Stream_Bindings.heartbeat(Client.streamClient(client))
}
