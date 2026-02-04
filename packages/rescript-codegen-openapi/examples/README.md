# rescript-codegen-openapi Examples

This directory contains working examples demonstrating the full capabilities of `rescript-codegen-openapi`.

## 🎯 What Makes This Library Unique

**Multi-Fork Support**: This is the ONLY OpenAPI codegen that can intelligently handle multiple API forks (like Misskey, Cherrypick, Firefish) by extracting shared code and generating fork-specific extensions. Perfect for federated/ActivityPub projects!

**Unified IR Pipeline**: Advanced type inference with a unified intermediate representation that generates both ReScript types AND Sury validation schemas from the same IR.

**Real-World Tested**: Tested with the Misskey/Cherrypick APIs (400+ endpoints, complex schemas).

---

## 📚 Examples

### Example 1: Generate from Single Spec
**File**: `01-generate-single-spec.mjs`

Generate a type-safe API client from any OpenAPI 3.1 spec.

```bash
node examples/01-generate-single-spec.mjs
```

**What it does:**
- Fetches Misskey API spec (439 endpoints)
- Generates ReScript types for all request/response schemas
- Generates Sury validation schemas with runtime type checking
- Creates per-tag modules (Admin.res, Notes.res, Users.res, etc.)
- Uses the unified IR pipeline for better type inference

**Output:**
```
examples/single-spec/generated/
├── Admin.res        (Admin endpoints)
├── Notes.res        (Notes endpoints)
├── Users.res        (User management)
└── ... (20+ modules)
```

**Use case:** 
- Single API integration
- Quick prototyping
- Learning the library

---

### Example 2: Compare Two Specs
**File**: `02-compare-specs.mjs`

Compare Misskey vs Cherrypick to find differences.

```bash
node examples/02-compare-specs.mjs
```

**What it does:**
- Fetches both Misskey and Cherrypick specs
- Compares endpoints and schemas
- Detects added/removed/modified endpoints
- Identifies breaking changes
- Generates detailed markdown report

**Output:**
```
examples/comparison/
└── misskey-vs-cherrypick-diff.md
```

**Sample findings:**
- 52 endpoints added in Cherrypick
- 0 endpoints removed (backward compatible!)
- 15 endpoints modified (schema changes)
- 3 breaking changes detected

**Use case:**
- API fork analysis
- Migration planning
- Documentation
- QA testing

---

### Example 3: Multi-Fork with Shared Base ⭐️ **UNIQUE FEATURE**
**File**: `03-generate-multi-fork.mjs`

Extract shared code between Misskey and Cherrypick, generate fork-specific extensions.

```bash
node examples/03-generate-multi-fork.mjs
```

**What it does:**
- Fetches Misskey (base) and Cherrypick (fork) specs
- Extracts ~387 shared endpoints with identical schemas
- Generates 52 Cherrypick-specific extensions
- Creates merge statistics and reports
- Maximum code reuse (~90% code sharing!)

**Output:**
```
examples/multi-fork/generated/
├── cherrypick.res              (Combined module)
├── cherrypick-diff.md          (Detailed differences)
└── cherrypick-merge.md         (Merge statistics)
```

**Generated code structure:**
```rescript
// Shared.res - Common to both Misskey and Cherrypick
module Shared = {
  module Admin = {
    // 30+ admin endpoints shared by both
  }
  module Notes = {
    // 50+ notes endpoints shared by both
  }
  // ... more shared modules
}

// CherrypickExtensions.res - Cherrypick-specific features
module CherrypickExtensions = {
  module Notes = {
    // 12 extra note-related endpoints
  }
  module Reactions = {
    // 8 extra reaction endpoints
  }
  // ... 52 unique endpoints total
}
```

**Use case:**
- Multi-fork projects (Misskey ecosystem)
- Code reuse across API variants
- Bundle size optimization
- Maintaining compatibility with multiple forks

**Why this is powerful:**
- ✨ **90% code reuse** - Shared endpoints generated once
- 🔧 **Easy maintenance** - Update shared code, extensions stay separate
- 🚀 **Type safety** - Full types for shared AND fork-specific APIs
- 📦 **Bundle optimization** - Tree-shaking removes unused code
- 🌳 **Scalable** - Add more forks (Firefish, Calckey) easily!

---

## 🚀 Quick Start

### Prerequisites

```bash
# Install dependencies
pnpm install

# Build the ReScript code
pnpm build
```

### Run Examples

```bash
# Example 1: Single spec
node examples/01-generate-single-spec.mjs

# Example 2: Compare specs
node examples/02-compare-specs.mjs

# Example 3: Multi-fork (recommended!)
node examples/03-generate-multi-fork.mjs
```

### Run All Examples

```bash
# Test the parser first
node examples/test-parser.mjs

# Then run all examples
for file in examples/0*.mjs; do node "$file"; done
```

---

## 📖 Understanding the Output

### ReScript Types

Generated types are type-safe and compatible with ReScript's type system:

```rescript
type createNoteRequest = {
  text: option<string>,
  visibility: [#public | #home | #followers | #specified],
  localOnly: option<bool>,
  reactionAcceptance: option<[#likeOnly | #likeOnlyForRemote | #nonSensitiveOnly | #nonSensitiveOnlyForLocalLikeOnlyForRemote]>,
}

type createNoteResponse = {
  createdNote: note,
}
```

### Sury Validation Schemas

Runtime validation schemas using [Sury](https://github.com/DZakh/rescript-schema):

```rescript
let createNoteRequestSchema = S.object(s => {
  text: s.field("text", S.option(S.string)),
  visibility: s.field("visibility", S.union([
    S.literal("public"),
    S.literal("home"),
    S.literal("followers"),
    S.literal("specified"),
  ])),
  localOnly: s.field("localOnly", S.option(S.bool)),
  // ... more fields
})
```

### Type-Safe Endpoint Functions

```rescript
// Create a note with validation
let createNote = (~body, ~fetch): promise<createNoteResponse> => {
  let validatedBody = createNoteRequestSchema->S.parseOrThrow(body)
  
  fetch(
    ~url="/api/notes/create",
    ~method_="POST",
    ~body=validatedBody,
  )->Promise.then(response => {
    let validatedResponse = createNoteResponseSchema->S.parseOrThrow(response)
    Promise.resolve(validatedResponse)
  })
}
```

---

## 🎨 Configuration Options

All examples accept a configuration object:

```javascript
const config = {
  // Required
  specPath: 'https://example.com/api.json',  // URL or file path
  outputDir: './generated',
  
  // Optional
  strategy: 'SharedBase',           // 'Separate' | 'SharedBase' | 'ConditionalCompilation'
  modulePerTag: true,               // Generate one module per API tag
  generateDiffReport: true,         // Generate markdown diff reports
  breakingChangeHandling: 'Warn',   // 'Ignore' | 'Warn' | 'Error'
  includeTags: undefined,           // Filter to specific tags
  excludeTags: undefined,           // Exclude specific tags
  
  // Multi-fork configuration
  forkSpecs: [
    { name: 'cherrypick', specPath: 'https://kokonect.link/api.json' },
    { name: 'firefish', specPath: 'https://firefish.example/api.json' },
  ],
};
```

### Strategy Options

- **`Separate`**: Generate complete code for each fork (no sharing)
- **`SharedBase`**: Extract shared code + fork extensions (recommended!)
- **`ConditionalCompilation`**: Generate one codebase with compile-time flags

---

## 🔍 Example Output

### Merge Report Sample

```markdown
# API Merge Report: Misskey → Cherrypick

## Summary
- Base endpoints: 439
- Fork endpoints: 491
- Shared endpoints: 387 (88%)
- Fork extensions: 52 (12%)

## Shared Endpoints (387)
These endpoints have identical schemas in both APIs:
- POST /api/admin/accounts/create
- POST /api/notes/create
- GET /api/users/show
... (384 more)

## Fork Extensions (52)
These endpoints are unique to Cherrypick:
- POST /api/notes/clips/add-note
- POST /api/reactions/custom/create
... (50 more)
```

---

## 🤔 When to Use Each Example

| Use Case | Example | Strategy |
|----------|---------|----------|
| Single API client | Example 1 | N/A |
| API comparison | Example 2 | N/A |
| Multi-fork project | Example 3 | SharedBase |
| Code reuse | Example 3 | SharedBase |
| Fork analysis | Example 2 + 3 | Both |

---

## 🐛 Troubleshooting

### "Failed to fetch spec"
- Check your internet connection
- Verify the API URL is correct
- Try increasing the timeout (default: 120s)

### "Failed to resolve $ref"
- The OpenAPI spec may have circular references
- Check the spec is valid OpenAPI 3.1
- File an issue with the problematic spec

### Build errors
```bash
# Clean and rebuild
pnpm clean
pnpm build
```

---

## 📚 Learn More

- [Main README](../README.md) - Library overview
- [API Documentation](../docs/api.md) - Full API reference
- [Architecture](../docs/architecture.md) - How it works under the hood
- [Misskey API](https://misskey.io/api-doc) - API we're testing against

---

## 🎯 Real-World Use Cases

### 1. ActivityPub Client
Use Example 3 to build a client that works with multiple Misskey forks:

```rescript
// Works with both Misskey and Cherrypick!
module Client = {
  open Shared.Notes
  open CherrypickExtensions.Notes
  
  let createNote = createNote  // Shared function
  let clipNote = clipNote      // Cherrypick-specific
}
```

### 2. API Migration Tool
Use Example 2 to plan migrations between API versions:

```bash
# Compare v13.0 vs v14.0
node examples/02-compare-specs.mjs \
  --base https://api.example.com/v13/openapi.json \
  --fork https://api.example.com/v14/openapi.json
```

### 3. Multi-Platform App
Use Example 3 to support multiple platforms with shared code:

```rescript
// 90% shared code
open Shared

// 10% platform-specific
switch platform {
| Cherrypick => open CherrypickExtensions
| Firefish => open FirefishExtensions
| Misskey => () // Use shared only
}
```

---

**🌟 Star us on GitHub if this helped you!**

**🐛 Found a bug? [Open an issue](https://github.com/yourusername/rescript-codegen-openapi/issues)**

**💡 Have a feature idea? We'd love to hear it!**
