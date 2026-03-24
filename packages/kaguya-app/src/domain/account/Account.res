// SPDX-License-Identifier: MPL-2.0

type t = {
  id: string,
  origin: string,
  token: string,
  username: string,
  host: string,
  avatarUrl: string,
  permissionMode: AuthTypes.permissionMode,
  misskeyUserId: string,
}

// Generate a unique account ID from origin + username
let makeId = (~origin: string, ~username: string): string => {
  username ++ "@" ++ origin
}

let displayLabel = (account: t): string => {
  "@" ++ account.username ++ "@" ++ account.host
}

// JSON Encoding/Decoding

let permissionModeToString = (mode: AuthTypes.permissionMode): string => {
  switch mode {
  | ReadOnly => "ReadOnly"
  | Standard => "Standard"
  }
}

let permissionModeFromString = (s: string): AuthTypes.permissionMode => {
  switch s {
  | "ReadOnly" => ReadOnly
  | _ => Standard
  }
}

let encode = (account: t): JSON.t => {
  let dict = Dict.make()
  dict->Dict.set("id", JSON.Encode.string(account.id))
  dict->Dict.set("origin", JSON.Encode.string(account.origin))
  dict->Dict.set("token", JSON.Encode.string(account.token))
  dict->Dict.set("username", JSON.Encode.string(account.username))
  dict->Dict.set("host", JSON.Encode.string(account.host))
  dict->Dict.set("avatarUrl", JSON.Encode.string(account.avatarUrl))
  dict->Dict.set("permissionMode", JSON.Encode.string(permissionModeToString(account.permissionMode)))
  dict->Dict.set("misskeyUserId", JSON.Encode.string(account.misskeyUserId))
  JSON.Encode.object(dict)
}

let decode = (json: JSON.t): option<t> => {
  json
  ->JSON.Decode.object
  ->Option.flatMap(obj => {
    let getString = (key: string): option<string> => {
      obj->Dict.get(key)->Option.flatMap(JSON.Decode.string)
    }

    switch (
      getString("id"),
      getString("origin"),
      getString("token"),
      getString("username"),
      getString("host"),
    ) {
    | (Some(id), Some(origin), Some(token), Some(username), Some(host)) =>
      Some({
        id,
        origin,
        token,
        username,
        host,
        avatarUrl: getString("avatarUrl")->Option.getOr(""),
        permissionMode: getString("permissionMode")
          ->Option.map(permissionModeFromString)
          ->Option.getOr(Standard),
        misskeyUserId: getString("misskeyUserId")->Option.getOr(""),
      })
    | _ => None
    }
  })
}

let encodeMany = (accounts: array<t>): JSON.t => {
  accounts->Array.map(encode)->JSON.Encode.array
}

let decodeMany = (json: JSON.t): array<t> => {
  json
  ->JSON.Decode.array
  ->Option.map(arr => arr->Array.filterMap(decode))
  ->Option.getOr([])
}

// Serialize/deserialize for localStorage
let serialize = (accounts: array<t>): string => {
  encodeMany(accounts)->JSON.stringify
}

let deserialize = (s: string): array<t> => {
  try {
    JSON.parseOrThrow(s)->decodeMany
  } catch {
  | _ => []
  }
}
