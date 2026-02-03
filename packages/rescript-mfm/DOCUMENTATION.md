# rescript-mfm Documentation

## Table of Contents

- [Installation](#installation)
- [Core Concepts](#core-concepts)
- [API Reference](#api-reference)
- [Node Types](#node-types)
- [Examples](#examples)
- [Advanced Usage](#advanced-usage)

## Installation

```bash
npm install rescript-mfm mfm-js
```

Add to your `rescript.json`:

```json
{
  "bs-dependencies": ["rescript-mfm"]
}
```

## Core Concepts

### What is MFM?

MFM (Misskey Flavored Markdown) is a markup language that extends Markdown with features specific to Misskey and the Fediverse:

- **Mentions**: `@username` or `@username@host.com`
- **Hashtags**: `#topic`
- **Custom Emoji**: `:emoji_name:`
- **Text Effects**: `$[effect content]` (e.g., `$[tada Hello!]`)
- **Math**: Inline `\(formula\)` or block `\[formula\]`
- **Standard Markdown**: `**bold**`, `*italic*`, `~~strike~~`, etc.

### Node Structure

All MFM nodes follow a simple structure:

```rescript
type node = {
  @as("type") type_: string,      // The node type (e.g., "text", "bold", "mention")
  props?: Dict.t<JSON.t>,         // Properties specific to the node type
  children?: array<node>,         // Child nodes (for container nodes)
}
```

## API Reference

### Parsing Functions

#### `parse`

```rescript
let parse: (~nestLimit: int=?, string) => array<node>
```

Parses MFM text into an array of nodes.

**Parameters:**
- `~nestLimit`: Optional maximum nesting depth (default: 20)
- `text`: The MFM text to parse

**Returns:** Array of parsed MFM nodes

**Example:**
```rescript
let nodes = Mfm.parse("Hello **world**!")
let limited = Mfm.parse(~nestLimit=5, text)
```

#### `parseSimple`

```rescript
let parseSimple: string => array<node>
```

Parses simple MFM (only emoji and text). Useful for parsing user names and other simple text where you only want emoji support.

**Example:**
```rescript
let nodes = Mfm.parseSimple("Hello :wave:")
```

### Stringify Functions

#### `toString`

```rescript
let toString: array<node> => string
```

Converts an array of nodes back to MFM text.

**Example:**
```rescript
let text = Mfm.toString(nodes)
```

#### `toStringNode`

```rescript
let toStringNode: node => string
```

Converts a single node to MFM text.

### Inspection Functions

#### `inspect`

```rescript
let inspect: (array<node>, node => unit) => unit
```

Recursively visits every node in the tree and executes a callback.

**Example:**
```rescript
Mfm.inspect(nodes, node => {
  Console.log(node.type_)
})
```

#### `extract`

```rescript
let extract: (array<node>, node => bool) => array<node>
```

Extracts all nodes that match a predicate function.

**Example:**
```rescript
let mentions = Mfm.extract(nodes, node => node.type_ === "mention")
```

### Utility Functions

#### `extractText`

```rescript
let extractText: array<node> => string
```

Extracts all text content from nodes, stripping all formatting.

**Example:**
```rescript
let plainText = Mfm.extractText(nodes)
// "**hello** world" becomes "hello world"
```

#### `getAllOfType`

```rescript
let getAllOfType: (array<node>, string) => array<node>
```

Gets all nodes of a specific type.

**Example:**
```rescript
let hashtags = Mfm.getAllOfType(nodes, "hashtag")
```

#### `containsType`

```rescript
let containsType: (array<node>, string) => bool
```

Checks if the tree contains any nodes of a specific type.

**Example:**
```rescript
if Mfm.containsType(nodes, "url") {
  Console.log("Contains URLs")
}
```

#### `getNodeType`

```rescript
let getNodeType: node => string
```

Gets the type of a node as a string.

#### `isNodeType`

```rescript
let isNodeType: (node, string) => bool
```

Checks if a node is of a specific type.

## Node Types

### Block Nodes

#### Quote

**Syntax:** `> text`

**Type:** `"quote"`

**Structure:**
```rescript
{
  type_: "quote",
  children: array<node>,
}
```

#### Code Block

**Syntax:**
```
```language
code
```
```

**Type:** `"blockCode"`

**Props:**
- `code`: The code content
- `lang`: The language name (null if not specified)

#### Math Block

**Syntax:**
```
\[
formula
\]
```

**Type:** `"mathBlock"`

**Props:**
- `formula`: The math formula

#### Center

**Syntax:**
```
<center>
content
</center>
```

**Type:** `"center"`

**Structure:**
```rescript
{
  type_: "center",
  children: array<node>,
}
```

#### Search

**Syntax:** `query [Search]` or `query Search`

**Type:** `"search"`

**Props:**
- `query`: The search query
- `content`: The full content including the button text

### Inline Nodes

#### Text

**Type:** `"text"`

**Props:**
- `text`: The text content

#### Bold

**Syntax:** `**text**` or `__text__` or `<b>text</b>`

**Type:** `"bold"`

#### Italic

**Syntax:** `*text*` or `_text_` or `<i>text</i>`

**Type:** `"italic"`

#### Strike

**Syntax:** `~~text~~` or `<s>text</s>`

**Type:** `"strike"`

#### Small

**Syntax:** `<small>text</small>`

**Type:** `"small"`

#### Inline Code

**Syntax:** `` `code` ``

**Type:** `"inlineCode"`

**Props:**
- `code`: The code content

#### Math Inline

**Syntax:** `\(formula\)`

**Type:** `"mathInline"`

**Props:**
- `formula`: The math formula

#### Unicode Emoji

**Type:** `"unicodeEmoji"`

**Props:**
- `emoji`: The emoji character

#### Emoji Code

**Syntax:** `:emoji_name:`

**Type:** `"emojiCode"`

**Props:**
- `name`: The emoji name

#### Mention

**Syntax:** `@username` or `@username@host.com`

**Type:** `"mention"`

**Props:**
- `username`: The username
- `host`: The host (null for local mentions)
- `acct`: The full account string

#### Hashtag

**Syntax:** `#tag`

**Type:** `"hashtag"`

**Props:**
- `hashtag`: The tag text

#### URL

**Syntax:** `https://example.com` or `<https://example.com>`

**Type:** `"url"`

**Props:**
- `url`: The URL
- `brackets`: Whether the URL was in brackets (optional)

#### Link

**Syntax:** `[label](url)` or `?[label](url)` (silent)

**Type:** `"link"`

**Props:**
- `silent`: Whether this is a silent link
- `url`: The URL

**Structure:**
```rescript
{
  type_: "link",
  props: { silent: bool, url: string },
  children: array<node>,
}
```

#### Function/Effect

**Syntax:** `$[name.param1,param2=value content]`

**Type:** `"fn"`

**Props:**
- `name`: The function name
- `args`: Dictionary of arguments

**Structure:**
```rescript
{
  type_: "fn",
  props: { name: string, args: Dict.t<JSON.t> },
  children: array<node>,
}
```

**Common functions:**
- `tada`: Animation effect
- `jelly`: Jelly animation
- `bounce`: Bounce animation
- `spin`: Spinning animation
- `shake`: Shake animation
- `twitch`: Twitch animation
- `rainbow`: Rainbow color effect

#### Plain

**Syntax:** `<plain>text</plain>`

**Type:** `"plain"`

**Description:** Content inside is not parsed as MFM

## Examples

### Example 1: Extract All Mentions

```rescript
let extractMentions = (text: string) => {
  let nodes = Mfm.parse(text)
  let mentions = Mfm.getAllOfType(nodes, "mention")
  
  mentions->Array.map(node => {
    switch node.props {
    | Some(props) => {
        let acct = Dict.get(props, "acct")
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("unknown")
        acct
      }
    | None => "unknown"
    }
  })
}

let text = "Hello @alice@example.com and @bob!"
let mentions = extractMentions(text)
// Result: ["@alice@example.com", "@bob"]
```

### Example 2: Strip All Formatting

```rescript
let stripFormatting = (text: string) => {
  let nodes = Mfm.parse(text)
  Mfm.extractText(nodes)
}

let formatted = "**Bold** and *italic* with :emoji:"
let plain = stripFormatting(formatted)
// Result: "Bold and italic with :emoji:"
```

### Example 3: Find URLs

```rescript
let findUrls = (text: string) => {
  let nodes = Mfm.parse(text)
  let urls = Mfm.getAllOfType(nodes, "url")
  
  urls->Array.map(node => {
    switch node.props {
    | Some(props) => 
      Dict.get(props, "url")
        ->Option.flatMap(JSON.Decode.string)
        ->Option.getOr("")
    | None => ""
    }
  })
}
```

### Example 4: Check for Sensitive Content

```rescript
let hasSensitiveContent = (text: string) => {
  let nodes = Mfm.parse(text)
  // Check for animated effects that might be distracting
  Mfm.containsType(nodes, "fn")
}
```

### Example 5: Validate Text Length

```rescript
let validateLength = (text: string, maxLength: int) => {
  let nodes = Mfm.parse(text)
  let plainText = Mfm.extractText(nodes)
  String.length(plainText) <= maxLength
}
```

## Advanced Usage

### Custom Node Processing

```rescript
let processNodes = (nodes: array<Mfm.node>, handler: Mfm.node => unit) => {
  nodes->Array.forEach(node => {
    handler(node)
    
    switch node.children {
    | Some(children) => processNodes(children, handler)
    | None => ()
    }
  })
}
```

### Converting to HTML

```rescript
let rec toHtml = (node: Mfm.node): string => {
  switch node.type_ {
  | "text" =>
    switch node.props {
    | Some(props) =>
      Dict.get(props, "text")
        ->Option.flatMap(JSON.Decode.string)
        ->Option.getOr("")
    | None => ""
    }
  | "bold" =>
    switch node.children {
    | Some(children) =>
      let content = children->Array.map(toHtml)->Array.join("")
      `<strong>${content}</strong>`
    | None => ""
    }
  | "italic" =>
    switch node.children {
    | Some(children) =>
      let content = children->Array.map(toHtml)->Array.join("")
      `<em>${content}</em>`
    | None => ""
    }
  | _ => ""
  }
}

let nodesToHtml = (nodes: array<Mfm.node>): string => {
  nodes->Array.map(toHtml)->Array.join("")
}
```

### Working with Function Nodes

```rescript
let getFunctionName = (node: Mfm.node): option<string> => {
  if node.type_ === "fn" {
    switch node.props {
    | Some(props) =>
      Dict.get(props, "name")->Option.flatMap(JSON.Decode.string)
    | None => None
    }
  } else {
    None
  }
}

let hasTadaEffect = (text: string): bool => {
  let nodes = Mfm.parse(text)
  let fnNodes = Mfm.getAllOfType(nodes, "fn")
  
  fnNodes->Array.some(node => {
    getFunctionName(node) == Some("tada")
  })
}
```

## Performance Tips

1. **Use `parseSimple` when possible**: If you only need emoji support, use `parseSimple` instead of `parse`

2. **Set appropriate nest limits**: Use `~nestLimit` to prevent excessive nesting

3. **Cache parsed results**: If you're displaying the same MFM content multiple times, parse once and cache the result

4. **Extract text early**: If you only need plain text, use `extractText` immediately after parsing

## Related Documentation

- [mfm-js documentation](https://github.com/misskey-dev/mfm.js)
- [MFM Specification (Japanese)](https://github.com/misskey-dev/mfm.js/blob/develop/docs/syntax.md)
