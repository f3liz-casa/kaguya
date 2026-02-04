// Account (Acct) utilities for parsing and formatting user identifiers
// Pure ReScript implementation - no external dependencies

type t = {
  username: string,
  host: option<string>,
}

// Parse a Misskey account string
// Examples:
//   "user" -> { username: "user", host: None }
//   "@user" -> { username: "user", host: None }
//   "user@example.com" -> { username: "user", host: Some("example.com") }
//   "@user@example.com" -> { username: "user", host: Some("example.com") }
let parse = (_acct: string): t => {
  // Remove leading @ if present
  let acct = _acct->String.startsWith("@") 
    ? _acct->String.slice(~start=1, ~end=String.length(_acct))
    : _acct
  
  // Split on @ with limit of 2 parts
  let parts = acct->String.split("@")
  
  // Check length and extract parts
  if Array.length(parts) == 0 {
    {username: "", host: None}
  } else if Array.length(parts) == 1 {
    {username: parts[0]->Option.getOr(""), host: None}
  } else {
    {
      username: parts[0]->Option.getOr(""),
      host: parts[1],
    }
  }
}

// Convert an Acct to string format
// Examples:
//   { username: "user", host: None } -> "user"
//   { username: "user", host: Some("example.com") } -> "user@example.com"
let toString = (acct: t): string => {
  switch acct.host {
  | None => acct.username
  | Some(host) => `${acct.username}@${host}`
  }
}

// Helper to create an acct
let make = (~username: string, ~host: option<string>=?, ()): t => {
  {username, host}
}

// Check if acct is local (no host)
let isLocal = (acct: t): bool => acct.host == None

// Check if acct is remote (has host)
let isRemote = (acct: t): bool => acct.host != None

// Get display name
let getDisplayName = (acct: t): string => {
  switch acct.host {
  | None => acct.username
  | Some(host) => `${acct.username}@${host}`
  }
}
