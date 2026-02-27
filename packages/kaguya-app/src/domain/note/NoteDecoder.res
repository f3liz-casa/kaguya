// SPDX-License-Identifier: MPL-2.0

open JsonUtils

// Decode reactions dict (emoji name -> count)
let decodeReactions = (reactionsOpt: option<JSON.t>): Dict.t<int> => {
  reactionsOpt
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(obj => {
    let result = Dict.make()
    obj->Dict.toArray->Array.forEach(((reaction, countJson)) => {
      countJson->JSON.Decode.float->Option.forEach(countFloat => {
        let count = Float.toInt(countFloat)
        if count > 0 { result->Dict.set(reaction, count) }
      })
    })
    result
  })
  ->Option.getOr(Dict.make())
}

// Decode reaction emojis dict (emoji name -> URL)
let decodeReactionEmojis = (emojisOpt: option<JSON.t>): Dict.t<string> => {
  emojisOpt
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(EmojiOps.extractFromJsonDict)
  ->Option.getOr(Dict.make())
}

// Decode files array
let decodeFiles = (filesOpt: option<JSON.t>): array<FileView.t> => {
  filesOpt
  ->Option.flatMap(JSON.Decode.array)
  ->Option.map(arr => arr->Array.filterMap(FileView.decode))
  ->Option.getOr([])
}

// Decode user and cache their custom emojis (used in display names for remote users)
let decodeUser = (userOpt: option<JSON.t>): UserView.t => {
  // Cache the user's own custom emojis so display name emojis resolve correctly
  userOpt
  ->Option.flatMap(JSON.Decode.object)
  ->Option.forEach(EmojiOps.extractAndCache)

  userOpt
  ->Option.flatMap(UserView.decode)
  ->Option.getOr({
    id: "",
    name: "Unknown",
    username: "unknown",
    avatarUrl: "",
    host: None,
  })
}

// Decode a single note (recursive for renotes)
let rec decode = (json: JSON.t): option<NoteView.t> => {
  json
  ->JSON.Decode.object
  ->Option.map(obj => {
    // Cache emojis side effect
    EmojiOps.extractAndCache(obj)

    let renote = obj->Dict.get("renote")->Option.flatMap(decode)
    let reply = obj->Dict.get("reply")->Option.flatMap(decode)

    // Ensure emojis from renote/reply are also cached
    [obj->Dict.get("renote"), obj->Dict.get("reply")]
    ->Array.forEach(opt => opt->Option.flatMap(JSON.Decode.object)->Option.forEach(EmojiOps.extractAndCache))

    let note: NoteView.t = {
      id: obj->stringOr("id", ""),
      user: decodeUser(obj->Dict.get("user")),
      text: obj->string("text"),
      cw: obj->string("cw"),
      createdAt: obj->stringOr("createdAt", ""),
      files: decodeFiles(obj->Dict.get("files")),
      reactions: decodeReactions(obj->Dict.get("reactions")),
      reactionEmojis: decodeReactionEmojis(obj->Dict.get("reactionEmojis")),
      myReaction: obj->string("myReaction"),
      reactionAcceptance: obj->Dict.get("reactionAcceptance")
        ->Option.flatMap(JSON.Decode.string)
        ->Option.flatMap(SharedTypes.reactionAcceptanceFromString),
      renote,
      replyId: obj->string("replyId"),
      reply,
      uri: obj->string("uri"),
    }
    note
  })
}

let decodeMany = (jsonArray: array<JSON.t>): array<NoteView.t> => {
  jsonArray->Array.filterMap(decode)
}

let decodeManyFromJson = (json: JSON.t): array<NoteView.t> => {
  json->JSON.Decode.array->Option.map(decodeMany)->Option.getOr([])
}
