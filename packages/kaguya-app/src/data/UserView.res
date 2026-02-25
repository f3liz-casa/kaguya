// SPDX-License-Identifier: MPL-2.0
// UserView.res - User data for display purposes

// ============================================================
// Types
// ============================================================

type t = {
  id: string,
  name: string, // Display name (defaults to username if not set)
  username: string,
  avatarUrl: string,
  host: option<string>, // For federated users
}

// ============================================================
// Computed Properties
// ============================================================

// Get full username with host (e.g., "@user@instance.com")
let fullUsername = (user: t): string => {
  switch user.host {
  | Some(h) => "@" ++ user.username ++ "@" ++ h
  | None => "@" ++ user.username
  }
}

// Get display name or username as fallback
let displayName = (user: t): string => {
  if user.name == "" {
    user.username
  } else {
    user.name
  }
}

// Check if user is local (no host)
let isLocal = (user: t): bool => {
  user.host->Option.isNone
}

// ============================================================
// Sury Schema
// ============================================================

// Raw type from JSON
type raw = {
  id: string,
  username: string,
  name: Nullable.t<string>,
  avatarUrl: string,
  host: Nullable.t<string>,
}

// Sury schema for user
let schema = S.object(s => {
  id: s.field("id", S.string),
  username: s.field("username", S.string),
  name: s.field("name", S.nullable(S.string)),
  avatarUrl: s.fieldOr("avatarUrl", S.string, ""),
  host: s.field("host", S.nullable(S.string)),
})

// Transform raw validated data to our type
let fromRaw = (raw: raw): t => {
  // Use username if name is not provided
  let name = raw.name->Nullable.toOption->Option.getOr(raw.username)

  // Fix avatar URL
  let avatarUrl = UrlUtils.fixAvatarUrl(raw.avatarUrl)

  {
    id: raw.id,
    name,
    username: raw.username,
    avatarUrl,
    host: raw.host->Nullable.toOption,
  }
}

// Parse from JSON using Sury
let parse = (json: JSON.t): result<t, S.error> => {
  try {
    let raw = json->S.parseOrThrow(schema)
    Ok(fromRaw(raw))
  } catch {
  | S.Error(e) => Error(e)
  }
}

// Convenient decode that returns option
let decode = (json: JSON.t): option<t> => {
  switch parse(json) {
  | Ok(user) => Some(user)
  | Error(e) => {
      Console.log2("UserView decode error message:", e.message)
      Console.log2("UserView decode error path:", e.path)
      Console.log2("Failed JSON:", json)
      None
    }
  }
}
