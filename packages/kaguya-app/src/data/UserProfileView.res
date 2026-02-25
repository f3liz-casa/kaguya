// SPDX-License-Identifier: MPL-2.0
// UserProfileView.res - Extended user data model for profile pages

type field = {
  fieldName: string,
  fieldValue: string,
}

type t = {
  id: string,
  name: string,
  username: string,
  avatarUrl: string,
  host: option<string>,
  description: option<string>,
  bannerUrl: option<string>,
  notesCount: int,
  followingCount: int,
  followersCount: int,
  pinnedNoteIds: array<string>,
  isBot: bool,
  createdAt: string,
  fields: array<field>,
}

// Get full @username or @username@host
let fullUsername = (user: t): string => {
  switch user.host {
  | Some(h) => "@" ++ user.username ++ "@" ++ h
  | None => "@" ++ user.username
  }
}

// Display name with fallback
let displayName = (user: t): string => {
  if user.name == "" {
    user.username
  } else {
    user.name
  }
}

let isLocal = (user: t): bool => {
  user.host->Option.isNone
}

// Decode from users/show API JSON response
let decode = (json: JSON.t): option<t> => {
  json
  ->JSON.Decode.object
  ->Option.map(obj => {
    let getString = (key: string): option<string> => {
      obj
      ->Dict.get(key)
      ->Option.flatMap(v => {
        switch v {
        | JSON.Null => None
        | _ => JSON.Decode.string(v)
        }
      })
    }

    let getStringOr = (key: string, default: string): string => {
      getString(key)->Option.getOr(default)
    }

    let getIntOr = (key: string, default: int): int => {
      obj
      ->Dict.get(key)
      ->Option.flatMap(JSON.Decode.float)
      ->Option.map(Float.toInt)
      ->Option.getOr(default)
    }

    let getBoolOr = (key: string, default: bool): bool => {
      obj
      ->Dict.get(key)
      ->Option.flatMap(JSON.Decode.bool)
      ->Option.getOr(default)
    }

    let pinnedNoteIds =
      obj
      ->Dict.get("pinnedNoteIds")
      ->Option.flatMap(JSON.Decode.array)
      ->Option.map(arr => arr->Array.filterMap(JSON.Decode.string))
      ->Option.getOr([])

    let fields =
      obj
      ->Dict.get("fields")
      ->Option.flatMap(JSON.Decode.array)
      ->Option.map(arr =>
        arr->Array.filterMap(fieldJson =>
          fieldJson
          ->JSON.Decode.object
          ->Option.flatMap(fieldObj => {
            let name =
              fieldObj
              ->Dict.get("name")
              ->Option.flatMap(JSON.Decode.string)
            let value =
              fieldObj
              ->Dict.get("value")
              ->Option.flatMap(JSON.Decode.string)
            switch (name, value) {
            | (Some(n), Some(v)) => Some({fieldName: n, fieldValue: v})
            | _ => None
            }
          })
        )
      )
      ->Option.getOr([])

    let avatarUrl = getString("avatarUrl")->Option.getOr("")

    {
      id: getStringOr("id", ""),
      name: getString("name")->Option.getOr(getStringOr("username", "")),
      username: getStringOr("username", ""),
      avatarUrl: UrlUtils.fixAvatarUrl(avatarUrl),
      host: getString("host"),
      description: getString("description"),
      bannerUrl: getString("bannerUrl"),
      notesCount: getIntOr("notesCount", 0),
      followingCount: getIntOr("followingCount", 0),
      followersCount: getIntOr("followersCount", 0),
      pinnedNoteIds,
      isBot: getBoolOr("isBot", false),
      createdAt: getStringOr("createdAt", ""),
      fields,
    }
  })
}
