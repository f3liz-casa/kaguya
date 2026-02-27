// SPDX-License-Identifier: MPL-2.0

type idleDeadline = {didTimeout: bool, timeRemaining: unit => float}
type idleCallbackId

@val external requestIdleCallback: (idleDeadline => unit) => idleCallbackId = "requestIdleCallback"
@val external requestIdleCallbackWithTimeout: (idleDeadline => unit, {"timeout": int}) => idleCallbackId = "requestIdleCallback"
@val external cancelIdleCallback: idleCallbackId => unit = "cancelIdleCallback"

let supportsIdleCallback = KaguyaNetwork.supportsIdleCallback

let emojis: PreactSignals.signal<EmojiTypes.emojiMap> = PreactSignals.make(Dict.make())
let loadState: PreactSignals.signal<EmojiTypes.loadState> = PreactSignals.make(EmojiTypes.NotLoaded)

let globalLoadAttempted: ref<bool> = ref(false)
let idlePrefetchStarted: ref<bool> = ref(false)
let imagePreloadStarted: ref<bool> = ref(false)

let getEmoji = (name: string): option<EmojiTypes.emoji> =>
  PreactSignals.value(emojis)->Dict.get(name)

let getEmojiUrl = (name: string): option<string> =>
  getEmoji(name)->Option.map(e => e.url)

let hasEmoji = (name: string): bool =>
  getEmoji(name)->Option.isSome

let getAllNames = (): array<string> =>
  PreactSignals.value(emojis)->Dict.keysToArray

let clear = (): unit => {
  PreactSignals.batch(() => {
    PreactSignals.setValue(emojis, Dict.make())
    PreactSignals.setValue(loadState, EmojiTypes.NotLoaded)
  })
  globalLoadAttempted := false
  EmojiCache.clearCache()
}

let addEmoji = (name: string, url: string, ~category: option<string>=?, ~aliases: array<string>=[]): unit => {
  let currentEmojis = PreactSignals.value(emojis)
  if currentEmojis->Dict.get(name)->Option.isNone {
    let newEmoji: EmojiTypes.emoji = {name, url, category, aliases}
    currentEmojis->Dict.set(name, newEmoji)
    aliases->Array.forEach(alias => {
      if alias != "" {
        currentEmojis->Dict.set(alias, newEmoji)
      }
    })
  }
}

let addEmojis = (emojiDict: Dict.t<string>): unit => {
  let currentEmojis = PreactSignals.value(emojis)
  emojiDict->Dict.toArray->Array.forEach(((name, url)) => {
    if currentEmojis->Dict.get(name)->Option.isNone {
      currentEmojis->Dict.set(name, {name, url, category: None, aliases: []})
    }
    let baseName = switch name->String.indexOf("@") {
    | -1 => name
    | index => name->String.substring(~start=0, ~end=index)
    }
    if baseName != name && currentEmojis->Dict.get(baseName)->Option.isNone {
      currentEmojis->Dict.set(baseName, {name: baseName, url, category: None, aliases: []})
    }
  })
}

let buildEmojiMap = (emojiList: array<Misskey.Emojis.customEmoji>): EmojiTypes.emojiMap => {
  let emojiMap: EmojiTypes.emojiMap = Dict.make()
  emojiList->Array.forEach(mjEmoji => {
    let emoji: EmojiTypes.emoji = {
      name: mjEmoji.name,
      url: mjEmoji.url,
      category: mjEmoji.category,
      aliases: mjEmoji.aliases,
    }
    emojiMap->Dict.set(emoji.name, emoji)
    let baseName = switch emoji.name->String.indexOf("@") {
    | -1 => emoji.name
    | index => emoji.name->String.substring(~start=0, ~end=index)
    }
    if baseName != emoji.name {
      emojiMap->Dict.set(baseName, emoji)
    }
    emoji.aliases->Array.forEach(alias => emojiMap->Dict.set(alias, emoji))
  })
  emojiMap
}

let load = async (client: Misskey.t): result<unit, string> => {
  let currentState = PreactSignals.value(loadState)
  if currentState == EmojiTypes.Loaded || currentState == EmojiTypes.Loading {
    Ok()
  } else {
    PreactSignals.setValue(loadState, EmojiTypes.Loading)
    globalLoadAttempted := true
    let instanceOrigin = client->Misskey.origin

    if EmojiCache.isCacheValid(instanceOrigin) {
      switch EmojiCache.loadFromCache() {
      | Some(cachedEmojis) => {
          PreactSignals.batch(() => {
            PreactSignals.setValue(emojis, cachedEmojis)
            PreactSignals.setValue(loadState, EmojiTypes.Loaded)
          })
          Ok()
        }
      | None => {
          let result = await client->Misskey.Emojis.list
          switch result {
          | Ok(emojiList) => {
              EmojiCache.saveToCache(emojiList, instanceOrigin)
              PreactSignals.batch(() => {
                PreactSignals.setValue(emojis, buildEmojiMap(emojiList))
                PreactSignals.setValue(loadState, EmojiTypes.Loaded)
              })
              Ok()
            }
          | Error(msg) => {
              PreactSignals.setValue(loadState, EmojiTypes.LoadError(msg))
              Ok()
            }
          }
        }
      }
    } else {
      let result = await client->Misskey.Emojis.list
      switch result {
      | Ok(emojiList) => {
          EmojiCache.saveToCache(emojiList, instanceOrigin)
          PreactSignals.batch(() => {
            PreactSignals.setValue(emojis, buildEmojiMap(emojiList))
            PreactSignals.setValue(loadState, EmojiTypes.Loaded)
          })
          Ok()
        }
      | Error(msg) => {
          PreactSignals.setValue(loadState, EmojiTypes.LoadError(msg))
          Ok()
        }
      }
    }
  }
}

let lazyLoadGlobal = async (client: Misskey.t): unit => {
  if !globalLoadAttempted.contents {
    let _ = await load(client)
  }
}

let reload = async (client: Misskey.t): result<unit, string> => {
  clear()
  await load(client)
}

let isLoaded: PreactSignals.computed<bool> = PreactSignals.computed(() =>
  PreactSignals.value(loadState) == EmojiTypes.Loaded
)

let isLoading: PreactSignals.computed<bool> = PreactSignals.computed(() =>
  PreactSignals.value(loadState) == EmojiTypes.Loading
)

let emojiCount: PreactSignals.computed<int> = PreactSignals.computed(() =>
  PreactSignals.value(emojis)->Dict.keysToArray->Array.length
)

let getAllEmojis = (): array<EmojiTypes.emoji> => {
  let seen = Dict.make()
  PreactSignals.value(emojis)
  ->Dict.valuesToArray
  ->Array.filter(emoji => {
    if seen->Dict.get(emoji.name)->Option.isSome {
      false
    } else {
      seen->Dict.set(emoji.name, true)
      true
    }
  })
}

let getEmojisByCategory = (): Dict.t<array<EmojiTypes.emoji>> => {
  let categories = Dict.make()
  getAllEmojis()->Array.forEach(emoji => {
    let cat = emoji.category->Option.getOr("Other")
    let existing = categories->Dict.get(cat)->Option.getOr([])
    existing->Array.push(emoji)
    categories->Dict.set(cat, existing)
  })
  categories
}

let getCategories = (): array<string> => {
  getEmojisByCategory()
  ->Dict.keysToArray
  ->Array.toSorted((a, b) =>
    if a == "Other" { 1.0 }
    else if b == "Other" { -1.0 }
    else { String.localeCompare(a, b) }
  )
}

let rec preloadEmojiImages = (batchSize: int, startIndex: int): unit => {
  let allEmojis = getAllEmojis()
  if startIndex < allEmojis->Array.length {
    let endIndex = Math.Int.min(startIndex + batchSize, allEmojis->Array.length)
    allEmojis
    ->Array.slice(~start=startIndex, ~end=endIndex)
    ->Array.forEach(emoji => ImagePreloader.preloadImage(emoji.url))
    if supportsIdleCallback() {
      let _ = requestIdleCallbackWithTimeout(_ => preloadEmojiImages(batchSize, endIndex), {"timeout": 30000})
    }
  }
}

let startImagePreload = (): unit => {
  if !imagePreloadStarted.contents && PreactSignals.value(loadState) == EmojiTypes.Loaded {
    imagePreloadStarted := true
    if supportsIdleCallback() {
      let _ = requestIdleCallbackWithTimeout(_ => preloadEmojiImages(5, 0), {"timeout": 30000})
    } else {
      let _ = SetTimeout.make(() => preloadEmojiImages(5, 0), 5000)
    }
  }
}

let prefetchDuringIdle = async (client: Misskey.t): unit => {
  if !idlePrefetchStarted.contents {
    idlePrefetchStarted := true
    let currentState = PreactSignals.value(loadState)
    if currentState != EmojiTypes.Loaded && currentState != EmojiTypes.Loading {
      if supportsIdleCallback() {
        let _ = requestIdleCallbackWithTimeout(_ => {
          let _ = load(client)->Promise.catch(_ => Promise.resolve(Ok()))
        }, {"timeout": 10000})
      } else {
        let _ = SetTimeout.make(() => {
          let _ = load(client)->Promise.catch(_ => Promise.resolve(Ok()))
        }, 2000)
      }
    }
  }
}
