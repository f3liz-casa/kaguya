// SPDX-License-Identifier: MPL-2.0

let storageKeyEmojis = "kaguya:emojis:data"
let storageKeyMetadata = "kaguya:emojis:metadata"
let cacheTTL = 1000.0 *. 60.0 *. 60.0 *. 24.0

let isCacheValid = (instanceOrigin: string): bool => {
  try {
    Storage.get(storageKeyMetadata)->Option.flatMap(str => {
      let metadata = JSON.parseOrThrow(str)->JSON.Decode.object
      let timestamp = metadata->Option.flatMap(o => o->Dict.get("timestamp"))->Option.flatMap(JSON.Decode.float)
      let cachedOrigin = metadata->Option.flatMap(o => o->Dict.get("instanceOrigin"))->Option.flatMap(JSON.Decode.string)
      switch (timestamp, cachedOrigin) {
      | (Some(ts), Some(origin)) => Some(origin == instanceOrigin && Date.now() -. ts < cacheTTL)
      | _ => None
      }
    })->Option.getOr(false)
  } catch {
  | _ => false
  }
}

let loadFromCache = (): option<EmojiTypes.emojiMap> => {
  try {
    Storage.get(storageKeyEmojis)->Option.flatMap(str => {
      JSON.parseOrThrow(str)->JSON.Decode.array->Option.map(arr => {
        let emojiMap: EmojiTypes.emojiMap = Dict.make()
        arr->Array.forEach(emojiJson => {
          emojiJson->JSON.Decode.object->Option.forEach(obj => {
            let name = obj->Dict.get("name")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
            let url = obj->Dict.get("url")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
            let category = obj->Dict.get("category")->Option.flatMap(v =>
              switch v {
              | JSON.Null => None
              | _ => JSON.Decode.string(v)
              }
            )
            let aliases =
              obj
              ->Dict.get("aliases")
              ->Option.flatMap(JSON.Decode.array)
              ->Option.map(a => a->Array.filterMap(JSON.Decode.string))
              ->Option.getOr([])

            if name != "" && url != "" {
              let emoji: EmojiTypes.emoji = {name, url, category, aliases}
              emojiMap->Dict.set(name, emoji)
              aliases->Array.forEach(alias => {
                if alias != "" {
                  emojiMap->Dict.set(alias, emoji)
                }
              })
              let baseName = switch name->String.indexOf("@") {
              | -1 => name
              | index => name->String.substring(~start=0, ~end=index)
              }
              if baseName != name {
                emojiMap->Dict.set(baseName, emoji)
              }
            }
          })
        })
        emojiMap
      })
    })
  } catch {
  | _ => None
  }
}

let saveToCache = (emojiList: array<Misskey.Emojis.customEmoji>, instanceOrigin: string): unit => {
  try {
    let emojiArray = emojiList->Array.map(emoji => {
      let obj = Dict.make()
      obj->Dict.set("name", JSON.Encode.string(emoji.name))
      obj->Dict.set("url", JSON.Encode.string(emoji.url))
      switch emoji.category {
      | Some(cat) => obj->Dict.set("category", JSON.Encode.string(cat))
      | None => obj->Dict.set("category", JSON.Encode.null)
      }
      obj->Dict.set("aliases", JSON.Encode.array(emoji.aliases->Array.map(JSON.Encode.string)))
      JSON.Encode.object(obj)
    })

    Storage.set(storageKeyEmojis, JSON.stringify(JSON.Encode.array(emojiArray)))

    let metadata = Dict.make()
    metadata->Dict.set("timestamp", JSON.Encode.float(Date.now()))
    metadata->Dict.set("instanceOrigin", JSON.Encode.string(instanceOrigin))
    Storage.set(storageKeyMetadata, JSON.stringify(JSON.Encode.object(metadata)))
  } catch {
  | _ => ()
  }
}

let clearCache = (): unit => {
  try {
    Storage.remove(storageKeyEmojis)
    Storage.remove(storageKeyMetadata)
  } catch {
  | _ => ()
  }
}
