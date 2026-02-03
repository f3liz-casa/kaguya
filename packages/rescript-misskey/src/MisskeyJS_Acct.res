// Account (Acct) utilities for parsing and formatting user identifiers

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
@module("misskey-js") @scope("acct")
external parse: string => t = "parse"

// Convert an Acct to string format
// Examples:
//   { username: "user", host: None } -> "user"
//   { username: "user", host: Some("example.com") } -> "user@example.com"
@module("misskey-js") @scope("acct")
external toString: t => string = "toString"

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
