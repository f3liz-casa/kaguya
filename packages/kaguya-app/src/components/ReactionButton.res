// SPDX-License-Identifier: MPL-2.0
// ReactionButton.res - Pure presentational component for a single reaction

@jsx.component
let make = (~reaction: string, ~count: int, ~reactionEmojis: Dict.t<string>) => {
  // Try to get emoji URL
  let emojiUrlOpt = if EmojiOps.isUnicodeEmoji(reaction) {
    None // Unicode emoji, will render as text
  } else {
    EmojiOps.getEmojiUrl(reaction, reactionEmojis)
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
    ~height="1.25em",
    ~width="auto",
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

  <div
    style={containerStyle}
    role="img"
    ariaLabel={reaction ++ " - " ++ Int.toString(count) ++ " reaction" ++ (count == 1 ? "" : "s")}
  >
    {switch emojiUrlOpt {
    | Some(url) => <img style={emojiStyle} src={url} alt={reaction} loading=#lazy />
    | None => {
        // Unicode emoji or missing custom emoji
        let unicodeStyle = Style.make(~fontSize="14px", ~flexShrink="0", ~lineHeight="1", ())
        <span style={unicodeStyle}> {Preact.string(reaction)} </span>
      }
    }}
    <span style={countStyle}> {Preact.string(Int.toString(count))} </span>
  </div>
}
