// SPDX-License-Identifier: MPL-2.0

let extractFromJsonDict = (emojisDict: Dict.t<JSON.t>): Dict.t<string> =>
  emojisDict
  ->Dict.toArray
  ->Array.filterMap(((name, urlJson)) =>
    urlJson->JSON.Decode.string->Option.map(url => (name, url))
  )
  ->Dict.fromArray

let cacheField = (noteObj: Dict.t<JSON.t>, field: string): unit =>
  noteObj
  ->Dict.get(field)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(extractFromJsonDict)
  ->Option.forEach(dict => {
    if dict->Dict.keysToArray->Array.length > 0 {
      EmojiStore.addEmojis(dict)
    }
  })

let extractAndCache = (noteObj: Dict.t<JSON.t>): unit => {
  cacheField(noteObj, "reactionEmojis")
  cacheField(noteObj, "emojis")
}

let getEmojiUrl = (reaction: string, reactionEmojis: Dict.t<string>): option<string> => {
  let emojiName = if String.startsWith(reaction, ":") && String.endsWith(reaction, ":") {
    reaction->String.slice(~start=1, ~end=String.length(reaction) - 1)
  } else {
    reaction
  }

  switch reactionEmojis->Dict.get(emojiName) {
  | Some(url) => Some(url)
  | None =>
    if String.endsWith(emojiName, "@.") {
      let baseName = emojiName->String.slice(~start=0, ~end=String.length(emojiName) - 2)
      switch EmojiStore.getEmojiUrl(baseName) {
      | Some(_) as result => result
      | None => EmojiStore.getEmojiUrl(emojiName)
      }
    } else {
      EmojiStore.getEmojiUrl(emojiName)
    }
  }
}

let isUnicodeEmoji = (reaction: string): bool =>
  !String.startsWith(reaction, ":")
