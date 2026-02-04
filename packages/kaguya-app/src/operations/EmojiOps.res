// SPDX-License-Identifier: MPL-2.0
// EmojiOps.res - Emoji extraction and caching operations

// ============================================================
// JSON Emoji Extraction
// ============================================================

// Extract emojis from a JSON dict (reusable for both reactionEmojis and emojis fields)
// Returns a Dict mapping emoji name to URL
let extractFromJsonDict = (emojisDict: Dict.t<JSON.t>): Dict.t<string> => {
  let result = Dict.make()

  emojisDict
  ->Dict.toArray
  ->Array.forEach(((name, urlJson)) => {
    switch urlJson->JSON.Decode.string {
    | Some(url) => result->Dict.set(name, url)
    | None => ()
    }
  })

  result
}

// ============================================================
// Note Emoji Extraction and Caching
// ============================================================

// Extract and cache emojis from a note object (JSON.t)
// This handles both the reactionEmojis field (emojis used as reactions)
// and the emojis field (custom emojis used in the note text)
let extractAndCache = (noteObj: Dict.t<JSON.t>): unit => {
  // Extract from reactionEmojis field
  noteObj
  ->Dict.get("reactionEmojis")
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(extractFromJsonDict)
  ->Option.forEach(dict => {
    if dict->Dict.keysToArray->Array.length > 0 {
      EmojiStore.addEmojis(dict)
    }
  })

  // Extract from emojis field (note text emojis)
  noteObj
  ->Dict.get("emojis")
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(extractFromJsonDict)
  ->Option.forEach(dict => {
    if dict->Dict.keysToArray->Array.length > 0 {
      EmojiStore.addEmojis(dict)
    }
  })
}

// ============================================================
// Emoji Lookup Helpers
// ============================================================

// Get emoji URL from a reaction string (e.g., ":emoji:" or ":emoji@instance:")
// First tries the provided reactionEmojis dict, then falls back to global store
let getEmojiUrl = (reaction: string, reactionEmojis: Dict.t<string>): option<string> => {
  // Remove leading and trailing colons (e.g., ":emoji:" -> "emoji")
  let emojiName = if String.startsWith(reaction, ":") && String.endsWith(reaction, ":") {
    reaction->String.slice(~start=1, ~end=String.length(reaction) - 1)
  } else {
    reaction
  }

  // Try reactionEmojis dict first (from note)
  switch reactionEmojis->Dict.get(emojiName) {
  | Some(url) => Some(url)
  | None =>
    // If ends with @., try both with and without suffix
    if String.endsWith(emojiName, "@.") {
      let baseName = emojiName->String.slice(~start=0, ~end=String.length(emojiName) - 2)
      switch EmojiStore.getEmojiUrl(baseName) {
      | Some(_) as result => result
      | None => EmojiStore.getEmojiUrl(emojiName)
      }
    } else {
      // Try global store
      EmojiStore.getEmojiUrl(emojiName)
    }
  }
}

// Check if a reaction is a unicode emoji (not a custom emoji with colons)
let isUnicodeEmoji = (reaction: string): bool => {
  !String.startsWith(reaction, ":")
}
