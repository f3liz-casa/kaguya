# rescript-mfm

ReScript bindings for [mfm-js](https://github.com/misskey-dev/mfm.js) - An MFM (Misskey Flavored Markdown) parser implementation.

## Installation

```bash
npm install rescript-mfm mfm-js
# or
yarn add rescript-mfm mfm-js
```

Add `rescript-mfm` to your `bsconfig.json` or `rescript.json`:

```json
{
  "bs-dependencies": ["rescript-mfm"]
}
```

## What is MFM?

MFM (Misskey Flavored Markdown) is a markup language used in Misskey and other Fediverse platforms. It extends standard Markdown with additional features like:

- Custom emoji syntax (`:emoji_name:`)
- Mentions (`@username@host`)
- Hashtags (`#hashtag`)
- Animated text effects (`$[tada Hello!]`)
- Math expressions (`\(x = y\)`)
- And more!

## Quick Start

```rescript
// Parse MFM text into nodes
let text = "Hello **world**! :emoji: @user@example.com #hashtag"
let nodes = Mfm.parse(text)

// Parse simple MFM (only emoji and text)
let simpleText = "I like the hot soup :soup:"
let simpleNodes = Mfm.parseSimple(simpleText)

// Convert nodes back to MFM text
let reconstructed = Mfm.toString(nodes)

// Extract plain text
let plainText = Mfm.extractText(nodes)
```

## Usage Examples

### Parsing with Options

```rescript
// Parse with custom nesting limit (default is 20)
let nodes = Mfm.parse(~nestLimit=10, text)
```

### Inspecting Nodes

```rescript
// Iterate over all nodes in the tree
Mfm.inspect(nodes, node => {
  Console.log(node.type_)
})

// Extract specific node types
let mentions = Mfm.extract(nodes, node => 
  node.type_ === "mention"
)
```

### Working with Specific Node Types

```rescript
// Get all mentions from parsed MFM
let getAllMentions = (nodes) => {
  Mfm.getAllOfType(nodes, "mention")
}

// Check if MFM contains hashtags
let hasHashtags = (nodes) => {
  Mfm.containsType(nodes, "hashtag")
}

// Get all emoji codes
let getEmojis = (nodes) => {
  Mfm.getAllOfType(nodes, "emojiCode")
}
```

### Example: Extracting Data from Nodes

```rescript
let extractMentionData = (node: Mfm.node) => {
  if node.type_ === "mention" {
    switch node.props {
    | Some(props) => {
        let username = Dict.get(props, "username")
          ->Option.flatMap(JSON.Decode.string)
        let host = Dict.get(props, "host")
          ->Option.flatMap(JSON.Decode.string)
        let acct = Dict.get(props, "acct")
          ->Option.flatMap(JSON.Decode.string)
        
        (username, host, acct)
      }
    | None => (None, None, None)
    }
  } else {
    (None, None, None)
  }
}

let mentions = Mfm.getAllOfType(nodes, "mention")
let mentionData = mentions->Array.map(extractMentionData)
```

## API Reference

### Parse Functions

- `parse: (~nestLimit: int=?, string) => array<node>`
  - Parses full MFM text into nodes
  - Optional `nestLimit` parameter (default: 20)

- `parseSimple: string => array<node>`
  - Parses simple MFM (emoji and text only)
  - Useful for user names and simple text

### Stringify Functions

- `toString: array<node> => string`
  - Converts an array of nodes back to MFM text

- `toStringNode: node => string`
  - Converts a single node back to MFM text

### Inspection Functions

- `inspect: (array<node>, node => unit) => unit`
  - Executes a callback for each node in the tree

- `inspectNode: (node, node => unit) => unit`
  - Executes a callback for a single node and its children

- `extract: (array<node>, node => bool) => array<node>`
  - Extracts nodes matching a predicate

### Utility Functions

- `extractText: array<node> => string`
  - Extracts all text content from nodes

- `getNodeType: node => string`
  - Gets the type of a node

- `isNodeType: (node, string) => bool`
  - Checks if a node is of a specific type

- `getAllOfType: (array<node>, string) => array<node>`
  - Gets all nodes of a specific type

- `containsType: (array<node>, string) => bool`
  - Checks if nodes contain a specific type

## Node Types

All MFM nodes have this structure:

```rescript
type node = {
  @as("type") type_: string,
  props?: Dict.t<JSON.t>,
  children?: array<node>,
}
```

### Block Node Types

- `quote` - Block quotes (`> text`)
- `search` - Search queries
- `blockCode` - Code blocks (` ```lang ... ``` `)
- `mathBlock` - Math blocks (`\[ ... \]`)
- `center` - Centered content (`<center>...</center>`)

### Inline Node Types

- `unicodeEmoji` - Unicode emoji (🎉)
- `emojiCode` - Custom emoji (`:emoji_name:`)
- `bold` - Bold text (`**text**`)
- `small` - Small text (`<small>...</small>`)
- `italic` - Italic text (`*text*` or `_text_`)
- `strike` - Strikethrough (`~~text~~`)
- `inlineCode` - Inline code (`` `code` ``)
- `mathInline` - Inline math (`\(formula\)`)
- `mention` - User mentions (`@user@host`)
- `hashtag` - Hashtags (`#tag`)
- `url` - URLs (`https://...`)
- `link` - Links (`[text](url)`)
- `fn` - Functions/effects (`$[effect content]`)
- `plain` - Plain text (no parsing)
- `text` - Plain text content

## Design Pattern

This package follows the **wrapper/bindings pattern** similar to other ReScript FFI libraries:

- **Direct bindings**: Low-level access to mfm-js through the `MfmNode.Raw` module
- **High-level API**: Convenient wrapper functions in the main `Mfm` module
- **Type-safe**: Uses ReScript's type system for safety while maintaining compatibility with the JavaScript API

## Examples

See the [examples](./examples) directory for more usage examples.

## License

MIT

## Related Projects

- [mfm-js](https://github.com/misskey-dev/mfm.js) - The underlying MFM parser library (TypeScript)
- [Misskey](https://github.com/misskey-dev/misskey) - The Fediverse platform that created MFM
- [rescript-misskey](../rescript-misskey) - ReScript bindings for misskey-js
