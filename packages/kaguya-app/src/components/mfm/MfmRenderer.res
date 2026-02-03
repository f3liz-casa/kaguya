// SPDX-License-Identifier: MPL-2.0
// MfmRenderer.res - Renders MFM nodes as Preact components

// Helper to get string from JSON props
let getPropString = (props: option<Dict.t<JSON.t>>, key: string): option<string> => {
  props
  ->Option.flatMap(p => Dict.get(p, key))
  ->Option.flatMap(JSON.Decode.string)
}

// Helper to get nullable string from JSON props
let getPropNullableString = (props: option<Dict.t<JSON.t>>, key: string): option<string> => {
  props
  ->Option.flatMap(p => Dict.get(p, key))
  ->Option.flatMap(v => {
    switch v {
    | JSON.Null => None
    | _ => JSON.Decode.string(v)
    }
  })
}

// Render a single MFM node
let rec renderNode = (node: Mfm.node, key: int): Preact.element => {
  let nodeType = node.type_

  switch nodeType {
  // Text node - basic text content
  | "text" =>
    switch getPropString(node.props, "text") {
    | Some(text) => Preact.string(text)
    | None => Preact.null
    }

  // Bold formatting
  | "bold" =>
    switch node.children {
    | Some(children) =>
      <strong key={Int.toString(key)}>
        {children->Array.mapWithIndex((child, i) => renderNode(child, i))->Preact.array}
      </strong>
    | None => Preact.null
    }

  // Italic formatting
  | "italic" =>
    switch node.children {
    | Some(children) =>
      <em key={Int.toString(key)}>
        {children->Array.mapWithIndex((child, i) => renderNode(child, i))->Preact.array}
      </em>
    | None => Preact.null
    }

  // Strikethrough
  | "strike" =>
    switch node.children {
    | Some(children) =>
      <del key={Int.toString(key)}>
        {children->Array.mapWithIndex((child, i) => renderNode(child, i))->Preact.array}
      </del>
    | None => Preact.null
    }

  // Small text
  | "small" =>
    switch node.children {
    | Some(children) =>
      <small key={Int.toString(key)}>
        {children->Array.mapWithIndex((child, i) => renderNode(child, i))->Preact.array}
      </small>
    | None => Preact.null
    }

  // Inline code
  | "inlineCode" =>
    switch getPropString(node.props, "code") {
    | Some(code) => <code key={Int.toString(key)}> {Preact.string(code)} </code>
    | None => Preact.null
    }

  // Block code
  | "blockCode" => {
      let code = getPropString(node.props, "code")->Option.getOr("")
      let lang = getPropNullableString(node.props, "lang")

      <pre key={Int.toString(key)} className="mfm-code-block">
        <code className={lang->Option.mapOr("", l => "language-" ++ l)}>
          {Preact.string(code)}
        </code>
      </pre>
    }

  // Quote block
  | "quote" =>
    switch node.children {
    | Some(children) =>
      <blockquote key={Int.toString(key)} className="mfm-quote">
        {children->Array.mapWithIndex((child, i) => renderNode(child, i))->Preact.array}
      </blockquote>
    | None => Preact.null
    }

  // Center block
  | "center" =>
    switch node.children {
    | Some(children) =>
      <div key={Int.toString(key)} className="mfm-center">
        {children->Array.mapWithIndex((child, i) => renderNode(child, i))->Preact.array}
      </div>
    | None => Preact.null
    }

  // URL
  | "url" =>
    switch getPropString(node.props, "url") {
    | Some(url) =>
      <a
        key={Int.toString(key)}
        href={url}
        target="_blank"
        rel="noopener noreferrer"
        className="mfm-url">
        {Preact.string(url)}
      </a>
    | None => Preact.null
    }

  // Link
  | "link" => {
      let url = getPropString(node.props, "url")->Option.getOr("#")
      let silent = node.props
        ->Option.flatMap(p => Dict.get(p, "silent"))
        ->Option.flatMap(JSON.Decode.bool)
        ->Option.getOr(false)

      switch node.children {
      | Some(children) =>
        <a
          key={Int.toString(key)}
          href={url}
          target="_blank"
          rel="noopener noreferrer"
          className={silent ? "mfm-link mfm-link-silent" : "mfm-link"}>
          {children->Array.mapWithIndex((child, i) => renderNode(child, i))->Preact.array}
        </a>
      | None => Preact.null
      }
    }

  // Mention
  | "mention" => {
      let username = getPropString(node.props, "username")->Option.getOr("unknown")
      let host = getPropNullableString(node.props, "host")
      let acct = getPropString(node.props, "acct")->Option.getOr("@" ++ username)

      <a
        key={Int.toString(key)}
        href={switch host {
        | Some(h) => `https://${h}/@${username}`
        | None => `/@${username}`
        }}
        className="mfm-mention">
        {Preact.string(acct)}
      </a>
    }

  // Hashtag
  | "hashtag" =>
    switch getPropString(node.props, "hashtag") {
    | Some(tag) =>
      <a key={Int.toString(key)} href={`/tags/${tag}`} className="mfm-hashtag">
        {Preact.string("#" ++ tag)}
      </a>
    | None => Preact.null
    }

  // Emoji code
  | "emojiCode" =>
    switch getPropString(node.props, "name") {
    | Some(name) => {
        // Try to get custom emoji from store
        switch EmojiStore.getEmoji(name) {
        | Some(emoji) =>
          <img
            key={Int.toString(key)}
            className="mfm-emoji-image"
            src={emoji.url}
            alt={`:${name}:`}
            title={`:${name}:`}
            loading=#"lazy"
          />
        | None => {
            // Emoji not found - trigger lazy load of global emojis
            // This will only happen once per session
            switch AppState.client->PreactSignals.value {
            | Some(client) => {
                let _ = EmojiStore.lazyLoadGlobal(client)
              }
            | None => ()
            }
            
            // Fallback to text for now
            // Note: The emoji might load on next render after global emojis are fetched
            <span key={Int.toString(key)} className="mfm-emoji-code">
              {Preact.string(":" ++ name ++ ":")}
            </span>
          }
        }
      }
    | None => Preact.null
    }

  // Unicode emoji
  | "unicodeEmoji" =>
    switch getPropString(node.props, "emoji") {
    | Some(emoji) =>
      <span key={Int.toString(key)} className="mfm-emoji"> {Preact.string(emoji)} </span>
    | None => Preact.null
    }

  // Math inline
  | "mathInline" =>
    switch getPropString(node.props, "formula") {
    | Some(formula) =>
      <span key={Int.toString(key)} className="mfm-math-inline">
        {Preact.string("\\(" ++ formula ++ "\\)")}
      </span>
    | None => Preact.null
    }

  // Math block
  | "mathBlock" =>
    switch getPropString(node.props, "formula") {
    | Some(formula) =>
      <div key={Int.toString(key)} className="mfm-math-block">
        {Preact.string("\\[" ++ formula ++ "\\]")}
      </div>
    | None => Preact.null
    }

  // Search
  | "search" =>
    switch getPropString(node.props, "query") {
    | Some(query) =>
      <div key={Int.toString(key)} className="mfm-search">
        <span> {Preact.string(query)} </span>
        <button className="mfm-search-button"> {Preact.string("Search")} </button>
      </div>
    | None => Preact.null
    }

  // Function/Effect
  | "fn" => {
      let name = getPropString(node.props, "name")->Option.getOr("unknown")

      switch node.children {
      | Some(children) =>
        <span key={Int.toString(key)} className={`mfm-fn mfm-fn-${name}`}>
          {children->Array.mapWithIndex((child, i) => renderNode(child, i))->Preact.array}
        </span>
      | None => Preact.null
      }
    }

  // Plain text (no parsing)
  | "plain" =>
    switch node.children {
    | Some(children) =>
      <span key={Int.toString(key)} className="mfm-plain">
        {children->Array.mapWithIndex((child, i) => renderNode(child, i))->Preact.array}
      </span>
    | None => Preact.null
    }

  // Unknown node type
  | _ => Preact.null
  }
}

// Component to render MFM text
@jsx.component
let make = (~text: string, ~parseSimple: bool=false) => {
  // Track render performance
  let _ = PerfMonitor.useRenderMetrics(~component="MfmRenderer")
  
  let nodes = if parseSimple {
    Mfm.parseSimple(text)
  } else {
    Mfm.parse(text)
  }

  <div className="mfm-content">
    {nodes->Array.mapWithIndex((node, i) => renderNode(node, i))->Preact.array}
  </div>
}
