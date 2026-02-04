// SPDX-License-Identifier: MPL-2.0
// NoteDecoder.res - Decode JSON from API to NoteView

// ============================================================
// Helper Functions
// ============================================================

// Get optional string from JSON dict
let getString = (obj: Dict.t<JSON.t>, key: string): option<string> => {
  obj
  ->Dict.get(key)
  ->Option.flatMap(value => {
    switch value {
    | JSON.Null => None
    | _ => JSON.Decode.string(value)
    }
  })
}

// Get string with default
let getStringOr = (obj: Dict.t<JSON.t>, key: string, default: string): string => {
  getString(obj, key)->Option.getOr(default)
}

// Decode reactions dict (emoji name -> count)
let decodeReactions = (reactionsOpt: option<JSON.t>): Dict.t<int> => {
  switch reactionsOpt->Option.flatMap(JSON.Decode.object) {
  | Some(reactionsObj) => {
      let result = Dict.make()
      reactionsObj
      ->Dict.toArray
      ->Array.forEach(((reaction, countJson)) => {
        switch countJson->JSON.Decode.float {
        | Some(countFloat) => {
            let count = Float.toInt(countFloat)
            if count > 0 {
              result->Dict.set(reaction, count)
            }
          }
        | None => ()
        }
      })
      result
    }
  | None => Dict.make()
  }
}

// Decode reaction emojis dict (emoji name -> URL)
let decodeReactionEmojis = (emojisOpt: option<JSON.t>): Dict.t<string> => {
  switch emojisOpt->Option.flatMap(JSON.Decode.object) {
  | Some(emojisDict) => EmojiOps.extractFromJsonDict(emojisDict)
  | None => Dict.make()
  }
}

// Decode reaction acceptance
let decodeReactionAcceptance = (valueOpt: option<JSON.t>): option<
  SharedTypes.reactionAcceptance,
> => {
  valueOpt
  ->Option.flatMap(JSON.Decode.string)
  ->Option.flatMap(SharedTypes.reactionAcceptanceFromString)
}

// Decode files array
let decodeFiles = (filesOpt: option<JSON.t>): array<FileView.t> => {
  switch filesOpt->Option.flatMap(JSON.Decode.array) {
  | Some(filesArray) => filesArray->Array.filterMap(FileView.decode)
  | None => []
  }
}

// Decode user
let decodeUser = (userOpt: option<JSON.t>): UserView.t => {
  switch userOpt->Option.flatMap(UserView.decode) {
  | Some(user) => user
  | None => // Fallback user
    {
      id: "",
      name: "Unknown",
      username: "unknown",
      avatarUrl: "",
      host: None,
    }
  }
}

// ============================================================
// Main Decoder
// ============================================================

// Decode a single note (recursive for renotes)
let rec decode = (json: JSON.t): option<NoteView.t> => {
  json
  ->JSON.Decode.object
  ->Option.map(obj => {
    // Cache emojis first (side effect, but necessary for emoji rendering)
    EmojiOps.extractAndCache(obj)

    // Decode user
    let user = decodeUser(obj->Dict.get("user"))

    // Decode renote recursively
    let renote = obj->Dict.get("renote")->Option.flatMap(decode)

    // Also extract emojis from renote if present
    renote->Option.forEach(_ => {
      // Re-extract from the original JSON to cache renote emojis
      obj
      ->Dict.get("renote")
      ->Option.flatMap(JSON.Decode.object)
      ->Option.forEach(EmojiOps.extractAndCache)
    })

    let note: NoteView.t = {
      id: getStringOr(obj, "id", ""),
      user,
      text: getString(obj, "text"),
      cw: getString(obj, "cw"),
      createdAt: getStringOr(obj, "createdAt", ""),
      files: decodeFiles(obj->Dict.get("files")),
      reactions: decodeReactions(obj->Dict.get("reactions")),
      reactionEmojis: decodeReactionEmojis(obj->Dict.get("reactionEmojis")),
      myReaction: getString(obj, "myReaction"),
      reactionAcceptance: decodeReactionAcceptance(obj->Dict.get("reactionAcceptance")),
      renote,
    }

    note
  })
}

// Decode array of notes (for timeline)
let decodeMany = (jsonArray: array<JSON.t>): array<NoteView.t> => {
  jsonArray->Array.filterMap(decode)
}

// Decode from JSON array value
let decodeManyFromJson = (json: JSON.t): array<NoteView.t> => {
  json
  ->JSON.Decode.array
  ->Option.map(decodeMany)
  ->Option.getOr([])
}
