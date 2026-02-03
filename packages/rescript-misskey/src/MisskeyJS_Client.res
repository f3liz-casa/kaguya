// Unified client that manages both REST API and WebSocket streaming
// This is the main entry point for most Misskey operations

module API_Bindings = MisskeyJS_API_Bindings
module Stream_Bindings = MisskeyJS_Stream_Bindings

// ============================================================
// Metrics Callback Types
// ============================================================

type apiCallMetrics = {
  endpoint: string,
  durationMs: float,
  success: bool,
}

type metricsCallback = apiCallMetrics => unit

// ============================================================
// Client Type
// ============================================================

// Internal representation
type rec t = {
  origin: string,
  credential: option<string>,
  apiClient: API_Bindings.t,
  mutable streamClient: option<Stream_Bindings.stream>,
  mutable metricsCallback: option<metricsCallback>,
}

// ============================================================
// Client Creation
// ============================================================

// Create a unified client
let make = (~origin: string, ~credential: option<string>=?, ()): t => {
  let apiClient = API_Bindings.make({
    origin,
    ?credential,
  })
  {
    origin,
    credential,
    apiClient,
    streamClient: None,
    metricsCallback: None,
  }
}

// ============================================================
// Metrics Callback Management
// ============================================================

// Set metrics callback for tracking API calls
let setMetricsCallback = (client: t, callback: metricsCallback): unit => {
  client.metricsCallback = Some(callback)
}

// Clear metrics callback
let clearMetricsCallback = (client: t): unit => {
  client.metricsCallback = None
}

// Internal: Track API call metrics
let trackApiCall = (client: t, ~endpoint: string, ~durationMs: float, ~success: bool): unit => {
  switch client.metricsCallback {
  | Some(callback) => callback({endpoint, durationMs, success})
  | None => ()
  }
}

// ============================================================
// Wrapped API Request
// ============================================================

// Wrapped request that tracks metrics
let request = async (
  client: t,
  ~endpoint: string,
  ~params: option<JSON.t>=?,
  ~credential: option<string>=?,
): JSON.t => {
  let startTime = Date.now()
  
  try {
    let result = switch (params, credential) {
    | (Some(p), Some(c)) => await API_Bindings.request(client.apiClient, ~endpoint, ~params=p, ~credential=c)
    | (Some(p), None) => await API_Bindings.request(client.apiClient, ~endpoint, ~params=p)
    | (None, Some(c)) => await API_Bindings.request(client.apiClient, ~endpoint, ~credential=c)
    | (None, None) => await API_Bindings.request(client.apiClient, ~endpoint)
    }
    let duration = Date.now() -. startTime
    trackApiCall(client, ~endpoint, ~durationMs=duration, ~success=true)
    result
  } catch {
  | error => {
      let duration = Date.now() -. startTime
      trackApiCall(client, ~endpoint, ~durationMs=duration, ~success=false)
      raise(error)
    }
  }
}

// ============================================================
// Accessors
// ============================================================
let origin = (client: t): string => client.origin
let credential = (client: t): option<string> => client.credential

// Get the underlying API client (for advanced use)
let apiClient = (client: t): API_Bindings.t => client.apiClient

// Get or lazily initialize the stream client
let streamClient = (client: t): Stream_Bindings.stream => {
  switch client.streamClient {
  | Some(stream) => stream
  | None => {
      let user = client.credential->Option.map(t => ({token: t}: Stream_Bindings.streamUser))
      let stream = Stream_Bindings.make(~origin=client.origin, ~user?, ())
      client.streamClient = Some(stream)
      stream
    }
  }
}

// Check if stream is connected
let isStreamConnected = (client: t): bool => {
  switch client.streamClient {
  | Some(stream) => Stream_Bindings.state(stream) == #connected
  | None => false
  }
}

// Stream connection event handlers
let onConnected = (client: t, callback: unit => unit): unit => {
  let stream = streamClient(client)
  Stream_Bindings.onConnected(stream, callback)
}

let onDisconnected = (client: t, callback: unit => unit): unit => {
  let stream = streamClient(client)
  Stream_Bindings.onDisconnected(stream, callback)
}

// Close the client (closes stream if open)
let close = (client: t): unit => {
  switch client.streamClient {
  | Some(stream) => Stream_Bindings.close(stream)
  | None => ()
  }
}
