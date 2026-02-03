# rescript-mfm Package Summary

## Overview

`rescript-mfm` is a ReScript wrapper/bindings package for [mfm-js](https://github.com/misskey-dev/mfm.js), providing type-safe access to MFM (Misskey Flavored Markdown) parsing functionality.

## Package Structure

```
rescript-mfm/
├── src/
│   ├── Mfm.res              # Main module with re-exports
│   ├── MfmAPI.res            # API functions (parse, toString, etc.)
│   └── MfmNode.res           # Type definitions for MFM nodes
├── examples/
│   └── BasicUsage.res        # Usage examples
├── README.md                 # Main documentation
├── DOCUMENTATION.md          # Detailed API reference
├── LICENSE                   # MIT License
├── package.json              # NPM package config
└── rescript.json            # ReScript compiler config
```

## Design Approach

Following the **Rust `-sys` pattern** (wrapper/bindings pattern):

1. **Raw Bindings Layer** (`MfmNode.Raw`): Direct FFI bindings to mfm-js
2. **High-Level API Layer** (`MfmAPI`, `Mfm`): Convenient ReScript-friendly wrappers
3. **Type Safety**: Uses ReScript's type system while maintaining JS interop

## Key Features

- ✅ Parse MFM text into AST nodes
- ✅ Parse simple MFM (emoji + text only)
- ✅ Convert AST back to MFM text
- ✅ Extract and filter nodes by type
- ✅ Extract plain text from formatted content
- ✅ Inspect and traverse node trees
- ✅ Configurable nesting limits
- ✅ Full TypeScript API coverage
- ✅ Comprehensive documentation

## API Surface

### Core Functions
- `parse(~nestLimit=?, string)` - Parse MFM text
- `parseSimple(string)` - Parse simple MFM
- `toString(array<node>)` - Convert to MFM text
- `extractText(array<node>)` - Extract plain text

### Node Inspection
- `inspect(nodes, callback)` - Traverse all nodes
- `extract(nodes, predicate)` - Filter nodes
- `getAllOfType(nodes, type)` - Get nodes by type
- `containsType(nodes, type)` - Check for type presence

## Supported MFM Features

### Block Elements
- Quotes (`> text`)
- Code blocks (` ```lang ... ``` `)
- Math blocks (`\[ ... \]`)
- Center tags (`<center>...</center>`)
- Search queries

### Inline Elements
- Text formatting: **bold**, *italic*, ~~strike~~, <small>small</small>
- Code: `inline code`
- Math: \(inline math\)
- Mentions: @user@host
- Hashtags: #tag
- URLs and links
- Custom emoji: :emoji:
- Unicode emoji: 🎉
- Effects: $[effect content]

## Dependencies

- **Runtime**: `mfm-js` ^0.25.0
- **Development**: `rescript` ^11.1.4, `@rescript/core` ^1.6.1

## Usage Example

```rescript
// Parse MFM
let nodes = Mfm.parse("Hello **world**! :wave:")

// Extract mentions
let mentions = Mfm.getAllOfType(nodes, "mention")

// Get plain text
let text = Mfm.extractText(nodes)

// Convert back to MFM
let mfm = Mfm.toString(nodes)
```

## Comparison with mfm-js

| Feature | mfm-js (TypeScript) | rescript-mfm |
|---------|---------------------|--------------|
| Parse MFM | ✅ | ✅ |
| Type safety | TypeScript | ReScript |
| Runtime validation | ❌ | ❌ (compile-time) |
| Bundle size | Same | Same |
| Performance | Native JS | Native JS (zero-cost wrapper) |
| API style | JS/TS | Functional ReScript |

## Future Enhancements

Possible additions (not implemented yet):
- Typed node constructors
- Pattern matching helpers
- Validation utilities
- Custom renderer framework
- Streaming parser support

## Related Packages

- [rescript-misskey](../rescript-misskey) - ReScript bindings for misskey-js
- [mfm-js](https://github.com/misskey-dev/mfm.js) - Upstream TypeScript parser

## Build Status

✅ Successfully compiles with ReScript 11.1.4
✅ All bindings working
✅ Examples included and tested
✅ Documentation complete

## License

MIT - Same as upstream mfm-js
