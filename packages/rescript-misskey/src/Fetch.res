// Fetch.res - Custom browser Fetch API bindings
// Minimal bindings for the browser Fetch API

// Fetch Request Init options
type requestInit

@obj
external makeRequestInit: (
  ~method: string=?,
  ~headers: JSON.t=?,
  ~body: string=?,
  unit,
) => requestInit = ""

// Response type
type response = {
  ok: bool,
  status: int,
  statusText: string,
}

// Response methods
@send external json: response => promise<JSON.t> = "json"
@send external text: response => promise<string> = "text"

// Main fetch function
@val
external fetch: (string, requestInit) => promise<response> = "fetch"

// Simplified fetch without options
@val
external fetchSimple: string => promise<response> = "fetch"
