# Project Summary

## What We Built

A complete ReScript binding and idiomatic wrapper library for [misskey-js](https://github.com/misskey-dev/misskey/tree/develop/packages/misskey-js), the official Misskey API client.

## Architecture Overview

The library follows a **two-layer architecture** inspired by Rust's `-sys` pattern:

### Layer 1: Low-Level Bindings (`internal/`)
- Direct FFI bindings to misskey-js
- Minimal abstraction over JavaScript
- Located in `src/internal/*_Bindings.res`

### Layer 2: High-Level Wrappers (Public API)
- Idiomatic ReScript interfaces
- Type-safe with Result types
- Polymorphic variants for enums
- Located in `src/MisskeyJS_*.res`

## Project Structure

```
rescript-misskey/
├── src/
│   ├── internal/                    # Low-level FFI bindings
│   │   ├── MisskeyJS_API_Bindings.res      # API client bindings
│   │   └── MisskeyJS_Stream_Bindings.res   # Streaming bindings
│   ├── types/                       # Entity type definitions
│   │   ├── MisskeyJS_User.res              # User types
│   │   ├── MisskeyJS_Note.res              # Note types
│   │   ├── MisskeyJS_Notification.res      # Notification types
│   │   └── MisskeyJS_Drive.res             # Drive types
│   ├── MisskeyJS_Common.res         # Common types and utilities
│   ├── MisskeyJS_API.res            # High-level API wrapper
│   ├── MisskeyJS_Stream.res         # High-level Streaming wrapper
│   ├── MisskeyJS_Acct.res           # Account utilities
│   ├── MisskeyJS_Constants.res      # Constants and enums
│   └── MisskeyJS.res                # Main module with re-exports
├── examples/                         # Usage examples
│   ├── BasicAPIExample.res
│   ├── StreamingExample.res
│   ├── AcctExample.res
│   └── ConstantsExample.res
├── docs/
│   └── API.md                        # Complete API documentation
├── package.json
├── bsconfig.json
├── README.md
└── CONTRIBUTING.md
```

## Features Implemented

### ✅ API Client
- [x] Client initialization with origin and credentials
- [x] Server metadata endpoints
- [x] Current user (I) endpoints
- [x] Notes CRUD operations
- [x] Note reactions
- [x] Timeline endpoints (home, local, global)
- [x] User operations
- [x] Following/unfollowing
- [x] Notifications
- [x] Drive file and folder management
- [x] Result-based error handling
- [x] APIError type guards

### ✅ Streaming
- [x] Stream initialization with WebSocket
- [x] Connection state management
- [x] Main channel (notifications, mentions, etc.)
- [x] Timeline channels (home, local, global, hybrid)
- [x] Drive channel (file/folder events)
- [x] Server stats channel
- [x] Connection lifecycle management
- [x] Auto-reconnection support (via misskey-js)

### ✅ Entity Types
- [x] User types (UserLite, UserDetailed, MeDetailed)
- [x] Note types with poll support
- [x] Notification discriminated union
- [x] Drive file and folder types
- [x] Common types (ID, dates, visibility, etc.)

### ✅ Utilities
- [x] Acct parsing and formatting
- [x] Constants (permissions, notification types, etc.)
- [x] Typed enum helpers
- [x] Nyaize function (cat mode)

### ✅ Documentation
- [x] Comprehensive README
- [x] Complete API documentation
- [x] Multiple usage examples
- [x] Contributing guidelines

## Key Design Decisions

### 1. Result Types for Error Handling
All API calls return `Result.t<'a, [#APIError(apiError) | #UnknownError(exn)]>` for type-safe error handling.

### 2. Polymorphic Variants for Enums
Used throughout for note visibility, notification types, etc., providing type safety without runtime overhead.

### 3. Labeled Arguments
All functions use labeled arguments for clarity and flexibility:
```rescript
API.make(~origin="...", ~credential=Some("..."), ())
```

### 4. Optional Parameters
Extensive use of optional parameters with the `?` syntax for flexibility.

### 5. JSON.t for Complex Types
Entity types use `JSON.t` for forward references and complex nested structures, allowing gradual typing.

### 6. Module Organization
Clear separation between:
- Low-level bindings (internal)
- High-level wrappers (public)
- Entity types (types/)
- Utilities (top-level)

## Usage Examples

### API Client
```rescript
let api = API.make(~origin="https://misskey.example", ~credential=Some("token"), ())

let result = await api->API.Notes.create(~params={
  text: Some("Hello from ReScript!"),
  visibility: Some(#public),
})

switch result {
| Ok(note) => Console.log("Success!", note)
| Error(#APIError(err)) => Console.log("Error:", err.message)
| Error(#UnknownError(_)) => Console.log("Unknown error")
}
```

### Streaming
```rescript
let stream = Stream.make(
  ~origin="https://misskey.example",
  ~user=Some({token: "token"}),
  ()
)

let main = stream->Stream.Main.use
main->Stream.Main.onNotification(notif => {
  Console.log("New notification:", notif)
})

let home = stream->Stream.HomeTimeline.use()
home->Stream.HomeTimeline.onNote(note => {
  Console.log("New note:", note)
})
```

## What's Not Included (Future Work)

### API Endpoints
Many Misskey endpoints exist beyond what we've bound:
- Admin endpoints
- Antennas
- Channels
- Clips
- Gallery
- Pages
- And many more...

These can be added incrementally as needed.

### Streaming Channels
Additional channels not yet bound:
- Chat channels
- Reversi game channels
- Queue stats
- User-specific channels

### Full Type Definitions
Currently using `JSON.t` for many entity types. Could expand to full ReScript types for better type safety.

### Testing
No automated tests yet. Would benefit from:
- Unit tests for utilities
- Integration tests with test Misskey instance
- Type-checking tests

## Extending the Library

The architecture makes it easy to extend:

1. **Add API endpoint**: Add binding in `API_Bindings.res`, wrapper in `API.res`
2. **Add streaming channel**: Add binding in `Stream_Bindings.res`, wrapper in `Stream.res`
3. **Add entity type**: Create new file in `types/`, export in `MisskeyJS.res`

See `CONTRIBUTING.md` for detailed guidelines.

## Dependencies

### Runtime
- `misskey-js` ^2026.1.0-beta.0 - The underlying JavaScript library
- `@rescript/core` ^1.7.0 - ReScript standard library

### Dev
- `rescript` ^11.1.4 - ReScript compiler

## Package Info

- **Name**: rescript-misskey
- **Version**: 0.1.0
- **License**: MIT
- **Build Target**: ES6 modules with in-source compilation

## Next Steps

To use this library:

1. **Install dependencies**: `npm install`
2. **Build**: `npm run build`
3. **Import in your ReScript project**:
   ```rescript
   open MisskeyJS
   
   let api = API.make(~origin="...", ~credential=Some("..."), ())
   ```

To contribute:
1. Read `CONTRIBUTING.md`
2. Check `docs/API.md` for API reference
3. Look at `examples/` for usage patterns

## Credits

This library provides ReScript bindings for [misskey-js](https://github.com/misskey-dev/misskey/tree/develop/packages/misskey-js), developed by the Misskey team.

Misskey is a decentralized social platform that's part of the Fediverse.
