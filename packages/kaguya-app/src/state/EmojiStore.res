// SPDX-License-Identifier: MPL-2.0
// EmojiStore.res - Global emoji cache using Preact Signals

// ============================================================
// Types
// ============================================================

type emoji = {
  name: string,
  url: string,
  category: option<string>,
  aliases: array<string>,
}

type emojiMap = Dict.t<emoji>

type loadState =
  | NotLoaded
  | Loading
  | Loaded
  | LoadError(string)

// Cache metadata for localStorage
type cacheMetadata = {
  timestamp: float,
  instanceOrigin: string,
}

// ============================================================
// LocalStorage Keys
// ============================================================

let storageKeyEmojis = "kaguya:emojis:data"
let storageKeyMetadata = "kaguya:emojis:metadata"
let cacheTTL = 1000.0 *. 60.0 *. 60.0 *. 24.0 // 24 hours in milliseconds

// ============================================================
// LocalStorage Bindings
// ============================================================

@val @scope("localStorage")
external getItem: string => Nullable.t<string> = "getItem"

@val @scope("localStorage")
external setItem: (string, string) => unit = "setItem"

@val @scope("localStorage")
external removeItem: string => unit = "removeItem"

// ============================================================
// Global Signals
// ============================================================

// Emoji cache: Dict with emoji name as key
let emojis: PreactSignals.signal<emojiMap> = PreactSignals.make(Dict.make())

// Load state
let loadState: PreactSignals.signal<loadState> = PreactSignals.make(NotLoaded)

// Track if we've attempted to load global emojis (to avoid multiple requests)
let globalLoadAttempted: ref<bool> = ref(false)

// Track if we've started idle prefetching
let idlePrefetchStarted: ref<bool> = ref(false)

// Track image preload state
let imagePreloadStarted: ref<bool> = ref(false)

// ============================================================
// requestIdleCallback Bindings
// ============================================================

type idleDeadline = {
  didTimeout: bool,
  timeRemaining: unit => float,
}

type idleCallbackId

@val
external requestIdleCallback: (idleDeadline => unit) => idleCallbackId = "requestIdleCallback"

@val
external requestIdleCallbackWithTimeout: (idleDeadline => unit, {"timeout": int}) => idleCallbackId = "requestIdleCallback"

@val
external cancelIdleCallback: idleCallbackId => unit = "cancelIdleCallback"

// Check if requestIdleCallback is supported
let supportsIdleCallback = (): bool => {
  try {
    %raw(`typeof requestIdleCallback !== 'undefined'`)
  } catch {
  | _ => false
  }
}

// ============================================================
// Helpers
// ============================================================

// Check if cache is valid
let isCacheValid = (instanceOrigin: string): bool => {
  try {
    let metadataStr = getItem(storageKeyMetadata)->Nullable.toOption
    
    switch metadataStr {
    | Some(str) => {
        let metadata = JSON.parseExn(str)
        
        switch (
          metadata->JSON.Decode.object
          ->Option.flatMap(obj => obj->Dict.get("timestamp"))
          ->Option.flatMap(JSON.Decode.float),
          metadata->JSON.Decode.object
          ->Option.flatMap(obj => obj->Dict.get("instanceOrigin"))
          ->Option.flatMap(JSON.Decode.string),
        ) {
        | (Some(timestamp), Some(cachedOrigin)) => {
            let age = Date.now() -. timestamp
            // Cache is valid if it's from the same instance and not expired
            cachedOrigin == instanceOrigin && age < cacheTTL
          }
        | _ => false
        }
      }
    | None => false
    }
  } catch {
  | _ => false
  }
}

// Load emojis from localStorage
let loadFromCache = (): option<emojiMap> => {
  try {
    let dataStr = getItem(storageKeyEmojis)->Nullable.toOption
    
    switch dataStr {
    | Some(str) => {
        let json = JSON.parseExn(str)
        
        // Parse the cached emoji array
        switch json->JSON.Decode.array {
        | Some(arr) => {
            let emojiMap = Dict.make()
            
            arr->Array.forEach(emojiJson => {
              switch emojiJson->JSON.Decode.object {
              | Some(obj) => {
                  let name = obj->Dict.get("name")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
                  let url = obj->Dict.get("url")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
                  let category = obj->Dict.get("category")->Option.flatMap(v => {
                    switch v {
                    | JSON.Null => None
                    | _ => JSON.Decode.string(v)
                    }
                  })
                  let aliases = obj->Dict.get("aliases")
                    ->Option.flatMap(JSON.Decode.array)
                    ->Option.map(arr => arr->Array.filterMap(JSON.Decode.string))
                    ->Option.getOr([])
                  
                  if name != "" && url != "" {
                    let emoji = {name, url, category, aliases}
                    emojiMap->Dict.set(name, emoji)
                    
                    // Also add aliases
                    aliases->Array.forEach(alias => {
                      if alias != "" {
                        emojiMap->Dict.set(alias, emoji)
                      }
                    })
                    
                    // Add base name without @instance
                    let baseName = switch name->String.indexOf("@") {
                    | -1 => name
                    | index => name->String.substring(~start=0, ~end=index)
                    }
                    if baseName != name {
                      emojiMap->Dict.set(baseName, emoji)
                    }
                  }
                }
              | None => ()
              }
            })
            
            Some(emojiMap)
          }
        | None => None
        }
      }
    | None => None
    }
  } catch {
  | _ => None
  }
}

// Save emojis to localStorage
let saveToCache = (emojiList: array<MisskeyJS.Emojis.customEmoji>, instanceOrigin: string): unit => {
  try {
    // Convert emoji list to JSON
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
    
    let dataJson = JSON.Encode.array(emojiArray)
    setItem(storageKeyEmojis, JSON.stringify(dataJson))
    
    // Save metadata
    let metadata = Dict.make()
    metadata->Dict.set("timestamp", JSON.Encode.float(Date.now()))
    metadata->Dict.set("instanceOrigin", JSON.Encode.string(instanceOrigin))
    
    let metadataJson = JSON.Encode.object(metadata)
    setItem(storageKeyMetadata, JSON.stringify(metadataJson))
    
    Console.log("EmojiStore: Saved to localStorage cache")
  } catch {
  | error => {
      Console.error2("EmojiStore: Failed to save to cache:", error)
    }
  }
}

// Clear localStorage cache
let clearCache = (): unit => {
  try {
    removeItem(storageKeyEmojis)
    removeItem(storageKeyMetadata)
  } catch {
  | _ => ()
  }
}

// Get emoji by name
let getEmoji = (name: string): option<emoji> => {
  let emojiMap = PreactSignals.value(emojis)
  emojiMap->Dict.get(name)
}

// Get emoji URL by name (convenience)
let getEmojiUrl = (name: string): option<string> => {
  getEmoji(name)->Option.map(e => e.url)
}

// Check if emoji exists
let hasEmoji = (name: string): bool => {
  getEmoji(name)->Option.isSome
}

// Get all emoji names
let getAllNames = (): array<string> => {
  let emojiMap = PreactSignals.value(emojis)
  emojiMap->Dict.keysToArray
}

// ============================================================
// Actions
// ============================================================

// Clear the emoji cache
let clear = (): unit => {
  PreactSignals.batch(() => {
    PreactSignals.setValue(emojis, Dict.make())
    PreactSignals.setValue(loadState, NotLoaded)
  })
  globalLoadAttempted := false
  clearCache()
}

// Add a single emoji to the cache
let addEmoji = (name: string, url: string, ~category: option<string>=?, ~aliases: array<string>=[]): unit => {
  let currentEmojis = PreactSignals.value(emojis)
  
  // Skip if already exists (lazy caching)
  if currentEmojis->Dict.get(name)->Option.isSome {
    ()
  } else {
    let newEmoji = {
      name,
      url,
      category,
      aliases,
    }
    
    // Mutate in place for performance (signal doesn't need to detect this)
    currentEmojis->Dict.set(name, newEmoji)
    
    // Also add aliases
    aliases->Array.forEach(alias => {
      if alias != "" {
        currentEmojis->Dict.set(alias, newEmoji)
      }
    })
  }
}

// Add multiple emojis at once (more efficient)
let addEmojis = (emojiDict: Dict.t<string>): unit => {
  let currentEmojis = PreactSignals.value(emojis)
  
  emojiDict->Dict.toArray->Array.forEach(((name, url)) => {
    // Store under the full name (with @instance)
    if currentEmojis->Dict.get(name)->Option.isNone {
      let newEmoji = {
        name,
        url,
        category: None,
        aliases: [],
      }
      currentEmojis->Dict.set(name, newEmoji)
    }
    
    // ALSO store under the base name (without @instance)
    // e.g., "emoji@misskey.io" -> "emoji"
    // e.g., "emoji@." -> "emoji" (local emojis)
    let baseName = switch name->String.indexOf("@") {
    | -1 => name // No @ found
    | index => name->String.substring(~start=0, ~end=index)
    }
    
    if baseName != name && currentEmojis->Dict.get(baseName)->Option.isNone {
      let newEmoji = {
        name: baseName,
        url,
        category: None,
        aliases: [],
      }
      currentEmojis->Dict.set(baseName, newEmoji)
    }
  })
}

// Add emojis from a note (note.emojis array)
let addEmojisFromNote = (noteEmojis: array<MisskeyJS.Common.emoji>): unit => {
  noteEmojis->Array.forEach(emoji => {
    addEmoji(emoji.name, emoji.url)
  })
}

// Convert MisskeyJS emoji to our emoji type
let convertEmoji = (mjEmoji: MisskeyJS.Emojis.customEmoji): emoji => {
  {
    name: mjEmoji.name,
    url: mjEmoji.url,
    category: mjEmoji.category,
    aliases: mjEmoji.aliases,
  }
}

// Load emojis from Misskey instance
let load = async (client: MisskeyJS.Client.t): result<unit, string> => {
  // Check if already loaded or loading
  let currentState = PreactSignals.value(loadState)
  if currentState == Loaded {
    Console.log("EmojiStore: Global emojis already loaded, skipping")
    Ok()
  } else if currentState == Loading {
    Console.log("EmojiStore: Global emojis already loading, skipping")
    Ok()
  } else {
    // Set loading state
    PreactSignals.setValue(loadState, Loading)
    globalLoadAttempted := true

    // Get instance origin for cache validation
    let instanceOrigin = MisskeyJS.Client.origin(client)
    
    // Try to load from localStorage cache first
    let cacheLoaded = if isCacheValid(instanceOrigin) {
      Console.log("EmojiStore: Loading from localStorage cache...")
      
      switch loadFromCache() {
      | Some(cachedEmojis) => {
          Console.log2("EmojiStore: Loaded from cache:", cachedEmojis->Dict.keysToArray->Array.length)
          
          PreactSignals.batch(() => {
            PreactSignals.setValue(emojis, cachedEmojis)
            PreactSignals.setValue(loadState, Loaded)
          })
          
          true
        }
      | None => {
          Console.log("EmojiStore: Cache load failed, fetching from API...")
          false
        }
      }
    } else {
      Console.log("EmojiStore: Cache invalid or expired, fetching from API...")
      false
    }
    
    // If cache was loaded successfully, return early
    if cacheLoaded {
      Ok()
    } else {
      // Fetch from API
      Console.log("EmojiStore: Loading global emojis from instance API...")

      let result = await MisskeyJS.Emojis.list(client)

      switch result {
      | Ok(emojiList) => {
          Console.log2("EmojiStore: Loaded global emojis from API:", emojiList->Array.length)
          
          // Save to cache for next time
          saveToCache(emojiList, instanceOrigin)
          
          // Convert to map with name as key
          let emojiMap = Dict.make()
          
          emojiList->Array.forEach(mjEmoji => {
            let emoji = convertEmoji(mjEmoji)
            
            // Store under full name
            emojiMap->Dict.set(emoji.name, emoji)
            
            // Also store under base name if it has @
            let baseName = switch emoji.name->String.indexOf("@") {
            | -1 => emoji.name
            | index => emoji.name->String.substring(~start=0, ~end=index)
            }
            if baseName != emoji.name {
              emojiMap->Dict.set(baseName, emoji)
            }
            
            // Also add aliases
            emoji.aliases->Array.forEach(alias => {
              emojiMap->Dict.set(alias, emoji)
            })
          })

          Console.log2("EmojiStore: Total emoji entries (with aliases):", emojiMap->Dict.keysToArray->Array.length)

          // Update signals
          PreactSignals.batch(() => {
            PreactSignals.setValue(emojis, emojiMap)
            PreactSignals.setValue(loadState, Loaded)
          })

          Ok()
        }
      | Error(#APIError(err)) => {
          let msg = "Global emoji load failed: " ++ err.message
          Console.error2("EmojiStore:", msg)
          PreactSignals.setValue(loadState, LoadError(msg))
          // Don't return error - notes can still use their own emoji data
          Ok()
        }
      | Error(#UnknownError(exn)) => {
          let msg = switch exn->Exn.asJsExn {
          | Some(jsExn) => Exn.message(jsExn)->Option.getOr("Unknown error loading global emojis")
          | None => "Unknown error loading global emojis"
          }
          Console.error2("EmojiStore:", msg)
          PreactSignals.setValue(loadState, LoadError(msg))
          // Don't return error - notes can still use their own emoji data
          Ok()
        }
      }
    }
  }
}

// Lazy load global emojis if not already loaded
// This is called when an emoji is not found in the per-note cache
let lazyLoadGlobal = async (client: MisskeyJS.Client.t): unit => {
  // Only attempt once to avoid spamming the server
  if globalLoadAttempted.contents {
    ()
  } else {
    let _ = await load(client)
  }
}

// Reload emojis (convenience)
let reload = async (client: MisskeyJS.Client.t): result<unit, string> => {
  clear()
  await load(client)
}

// ============================================================
// Computed Signals
// ============================================================

let isLoaded: PreactSignals.computed<bool> = PreactSignals.computed(() => {
  switch PreactSignals.value(loadState) {
  | Loaded => true
  | _ => false
  }
})

let isLoading: PreactSignals.computed<bool> = PreactSignals.computed(() => {
  switch PreactSignals.value(loadState) {
  | Loading => true
  | _ => false
  }
})

let emojiCount: PreactSignals.computed<int> = PreactSignals.computed(() => {
  let emojiMap = PreactSignals.value(emojis)
  emojiMap->Dict.keysToArray->Array.length
})

// ============================================================
// Emoji Helpers for Picker
// ============================================================

// Get all emojis as a flat array (for search and display)
let getAllEmojis = (): array<emoji> => {
  let emojiMap = PreactSignals.value(emojis)
  let seen = Dict.make()
  let result = []
  
  // Deduplicate by name (since we store both "emoji" and "emoji@instance")
  emojiMap->Dict.toArray->Array.forEach(((_, emoji)) => {
    if seen->Dict.get(emoji.name)->Option.isNone {
      seen->Dict.set(emoji.name, true)
      result->Array.push(emoji)
    }
  })
  
  result
}

// Get all emojis grouped by category
let getEmojisByCategory = (): Dict.t<array<emoji>> => {
  let allEmojis = getAllEmojis()
  let categories = Dict.make()
  
  allEmojis->Array.forEach(emoji => {
    let cat = emoji.category->Option.getOr("Other")
    let existing = categories->Dict.get(cat)->Option.getOr([])
    existing->Array.push(emoji)
    categories->Dict.set(cat, existing)
  })
  
  categories
}

// Get all category names
let getCategories = (): array<string> => {
  getEmojisByCategory()->Dict.keysToArray->Array.toSorted((a, b) => {
    // Sort alphabetically, but keep "Other" at the end
    if a == "Other" {
      1.0
    } else if b == "Other" {
      -1.0
    } else {
      String.localeCompare(a, b)
    }
  })
}

// ============================================================
// Idle Time Prefetching
// ============================================================

// Preload emoji images in batches during idle time
let rec preloadEmojiImages = (batchSize: int, startIndex: int): unit => {
  let allEmojis = getAllEmojis()
  let totalEmojis = allEmojis->Array.length
  
  if startIndex >= totalEmojis {
    Console.log("EmojiStore: All emoji images preloaded")
    ()
  } else {
    let endIndex = Math.Int.min(startIndex + batchSize, totalEmojis)
    let batch = allEmojis->Array.slice(~start=startIndex, ~end=endIndex)
    
    // Preload images in this batch
    batch->Array.forEach(emoji => {
      ImagePreloader.preloadImage(emoji.url)
    })
    
    Console.log3(
      "EmojiStore: Preloaded images",
      endIndex,
      "/" ++ totalEmojis->Int.toString,
    )
    
    // Schedule next batch during idle time with much longer delay
    // Use a 3 second timeout to avoid spamming requests
    if supportsIdleCallback() {
      let _ = requestIdleCallbackWithTimeout(
        _deadline => {
          preloadEmojiImages(batchSize, endIndex)
        },
        {"timeout": 30000}, // 30 seconds timeout - very conservative
      )
    }
    ()
  }
}

// Start preloading emoji images during idle time
let startImagePreload = (): unit => {
  if !imagePreloadStarted.contents && PreactSignals.value(loadState) == Loaded {
    imagePreloadStarted := true
    
    Console.log("EmojiStore: Starting idle-time image preload...")
    
    // Start preloading in small batches of 5 emojis with long delays
    if supportsIdleCallback() {
      let _ = requestIdleCallbackWithTimeout(
        _deadline => {
          preloadEmojiImages(5, 0) // Reduced from 20 to 5
        },
        {"timeout": 30000}, // 30 seconds timeout
      )
    } else {
      // Fallback: use setTimeout with a long delay
      let timeoutId = SetTimeout.make(() => {
        preloadEmojiImages(5, 0)
      }, 5000)
      let _ = timeoutId // Suppress unused warning
    }
    ()
  }
}

// Prefetch emojis during idle time
// This is called after the app initializes to warm up the emoji cache
let prefetchDuringIdle = async (client: MisskeyJS.Client.t): unit => {
  // Only prefetch once
  if idlePrefetchStarted.contents {
    ()
  } else {
    idlePrefetchStarted := true
    
    // Check if already loaded
    let currentState = PreactSignals.value(loadState)
    if currentState == Loaded {
      Console.log("EmojiStore: Emojis already loaded")
      // NOTE: Image preloading disabled to avoid spamming requests
      // Virtual scrolling handles rendering performance
      ()
    } else if currentState == Loading {
      Console.log("EmojiStore: Emojis already loading...")
      ()
    } else {
      // Not loaded yet - load during idle time
      if supportsIdleCallback() {
        Console.log("EmojiStore: Scheduling idle-time emoji prefetch...")
        
        let _ = requestIdleCallbackWithTimeout(
          _deadline => {
            let _ = {
              open Promise
              load(client)
              ->thenResolve(_ => {
                Console.log("EmojiStore: Idle prefetch completed")
                // NOTE: Image preloading disabled to avoid request spam
              })
              ->catch(err => {
                Console.error2("EmojiStore: Idle prefetch failed:", err)
                resolve()
              })
            }
          },
          {"timeout": 10000}, // Timeout after 10 seconds
        )
      } else {
        // Fallback: use setTimeout with a delay
        Console.log("EmojiStore: requestIdleCallback not supported, using setTimeout fallback...")
        let timeoutId = SetTimeout.make(() => {
          let _ = {
            open Promise
            load(client)
            ->thenResolve(_ => {
              Console.log("EmojiStore: Idle prefetch completed (fallback)")
            })
            ->catch(err => {
              Console.error2("EmojiStore: Idle prefetch failed (fallback):", err)
              resolve()
            })
          }
        }, 2000)
        let _ = timeoutId // Suppress unused warning
      }
      ()
    }
  }
}
