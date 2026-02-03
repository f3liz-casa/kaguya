// SPDX-License-Identifier: MPL-2.0
// ReactionButton.res - Pure presentational component for a single reaction

// ============================================================
// Helpers
// ============================================================

// Get emoji URL from reaction string
let getEmojiUrl = (reaction: string, reactionEmojis: Dict.t<string>): option<string> => {
  // Remove only the leading and trailing colons (e.g., ":emoji:" -> "emoji", ":emoji@.:" -> "emoji@.")
  let emojiName = if String.startsWith(reaction, ":") && String.endsWith(reaction, ":") {
    reaction->String.slice(~start=1, ~end=String.length(reaction) - 1)
  } else {
    reaction
  }
  
  // First try to get from reactionEmojis dict (from note)
  switch reactionEmojis->Dict.get(emojiName) {
  | Some(url) => Some(url)
  | None => {
      // If not found and ends with @., try looking up in global store
      // The @. means "local instance" but the reactionEmojis dict might store it differently
      if String.endsWith(emojiName, "@.") {
        // Try without @. suffix in global store
        let baseNameWithoutHost = emojiName->String.slice(~start=0, ~end=String.length(emojiName) - 2)
        switch EmojiStore.getEmojiUrl(baseNameWithoutHost) {
        | Some(_) as result => result
        | None => {
            // Also try the full name with @. in global store
            EmojiStore.getEmojiUrl(emojiName)
          }
        }
      } else {
        // Try global emoji store
        EmojiStore.getEmojiUrl(emojiName)
      }
    }
  }
}

// Check if reaction is unicode emoji (not a custom emoji)
let isUnicodeEmoji = (reaction: string): bool => {
  !String.startsWith(reaction, ":")
}

// ============================================================
// Component
// ============================================================

@jsx.component
let make = (
  ~reaction: string,
  ~count: int,
  ~reactionEmojis: Dict.t<string>,
) => {
  // Try to get emoji URL
  let emojiUrlOpt = if isUnicodeEmoji(reaction) {
    None // Unicode emoji, will render as text
  } else {
    getEmojiUrl(reaction, reactionEmojis)
  }
  
  let containerStyle = Style.make(
    ~display="flex",
    ~alignItems="center",
    ~justifyContent="center",
    ~gap="3px",
    ~overflow="hidden",
    ~textOverflow="ellipsis",
    (),
  )
  
  let emojiStyle = Style.make(
    ~width="14px",
    ~height="14px",
    ~flexShrink="0",
    ~objectFit="contain",
    (),
  )
  
  let countStyle = Style.make(
    ~fontSize="11px",
    ~fontWeight="500",
    ~flexShrink="0",
    ~lineHeight="1",
    (),
  )
  
  <div style={containerStyle} role="img" ariaLabel={reaction ++ " - " ++ Int.toString(count) ++ " reaction" ++ (count == 1 ? "" : "s")}>
    {switch emojiUrlOpt {
    | Some(url) => {
        <img
          style={emojiStyle}
          src={url}
          alt={reaction}
          loading=#"lazy"
        />
      }
      | None => {
         // Unicode emoji or missing custom emoji
         let unicodeStyle = Style.make(
           ~fontSize="14px",
           ~flexShrink="0",
           ~lineHeight="1",
           (),
         )
         <span style={unicodeStyle}> {Preact.string(reaction)} </span>
       }
    }}
    <span style={countStyle}> {Preact.string(Int.toString(count))} </span>
  </div>
}
