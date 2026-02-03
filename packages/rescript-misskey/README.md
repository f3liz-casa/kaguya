# rescript-misskey

ReScript bindings and idiomatic wrappers for [misskey-js](https://github.com/misskey-dev/misskey), the official Misskey API client library.

> **Status**: ✅ Full port complete with comprehensive API coverage, streaming support, and extensive documentation!

## Quick Links

- 📚 [API Documentation](docs/API.md) - Complete API reference
- 🚀 [Quick Start Guide](QUICKSTART.md) - Get started in 5 minutes
- 💡 [Examples](examples/) - Real-world usage examples
- 🤝 [Contributing](CONTRIBUTING.md) - How to contribute
- 📋 [Project Summary](PROJECT_SUMMARY.md) - Architecture overview

## Architecture

This library follows a two-layer approach similar to Rust's `-sys` pattern:

1. **Low-level bindings** (`*_Bindings` modules): Direct FFI bindings to misskey-js with minimal abstraction
2. **High-level wrappers** (public API): Idiomatic ReScript interfaces with type safety, result types, and ReScript conventions

## Installation

```bash
npm install rescript-misskey misskey-js
```

Add to your `bsconfig.json`:

```json
{
  "bs-dependencies": ["rescript-misskey"]
}
```

## Quick Start

### API Client

```rescript
open MisskeyJS

// Create an API client
let api = API.make(
  ~origin="https://misskey.example",
  ~credential=Some("your-token"),
  ()
)

// Make API requests with Result types
let result = await api->API.Notes.create(~params={
  text: Some("Hello from ReScript!"),
  visibility: Some(#public),
})

switch result {
| Ok(note) => Console.log("Note created!", note)
| Error(#APIError(err)) => Console.log("API Error:", err.message)
| Error(#UnknownError(_)) => Console.log("Unknown error")
}
```

### Streaming

```rescript
open MisskeyJS

// Create a stream connection
let stream = Stream.make(
  ~origin="https://misskey.example",
  ~user=Some({token: "your-token"}),
  ()
)

// Connect to main channel for notifications
let main = stream->Stream.Main.use

main->Stream.Main.onNotification(notification => {
  Console.log("New notification:", notification)
})

// Connect to home timeline
let home = stream->Stream.HomeTimeline.use(
  ~params=Some({withRenotes: Some(true)}),
  ()
)

home->Stream.HomeTimeline.onNote(note => {
  Console.log("New note:", note)
})

// Cleanup
main->Stream.Main.dispose
home->Stream.HomeTimeline.dispose
stream->Stream.close
```

**👉 See [QUICKSTART.md](QUICKSTART.md) for a complete guide!**

## Module Structure

```
MisskeyJS/
├── API.res                    // High-level API client
├── Stream.res                 // High-level streaming client
├── Channel.res                // Channel connection interface
├── Types/
│   ├── User.res              // User entity types
│   ├── Note.res              // Note entity types
│   ├── Notification.res      // Notification types
│   ├── Drive.res             // Drive types
│   └── ...
├── Acct.res                  // Account utilities
├── Constants.res             // Constants and enums
└── Internal/
    ├── API_Bindings.res      // Low-level API bindings
    ├── Stream_Bindings.res   // Low-level stream bindings
    └── ...
```

## Features

### API Client
- ✅ Server metadata and user info
- ✅ Notes: create, delete, show, reactions
- ✅ Timelines: home, local, global
- ✅ Users: show, follow, unfollow
- ✅ Notifications: get, mark as read
- ✅ Drive: files and folders management
- ✅ Result-based error handling

### Streaming (WebSocket)
- ✅ Main channel (notifications, mentions, etc.)
- ✅ Timeline channels (home, local, global, hybrid)
- ✅ Drive events (files, folders)
- ✅ Server stats (admin)
- ✅ Auto-reconnection support

### Type Safety
- ✅ Comprehensive entity types (User, Note, Notification, Drive)
- ✅ Polymorphic variants for enums
- ✅ Result types for error handling
- ✅ Labeled arguments throughout

### Developer Experience
- ✅ Idiomatic ReScript API
- ✅ Complete documentation with examples
- ✅ Full TypeScript interop
- ✅ Tree-shakeable exports

## Examples

Check out the [examples/](examples/) directory for complete examples:

- **[BasicAPIExample.res](examples/BasicAPIExample.res)** - API client usage (notes, users, timelines)
- **[StreamingExample.res](examples/StreamingExample.res)** - WebSocket streaming and channels
- **[AcctExample.res](examples/AcctExample.res)** - Account identifier parsing
- **[ConstantsExample.res](examples/ConstantsExample.res)** - Constants and utilities

## Documentation

- **[API Documentation](docs/API.md)** - Complete API reference with all endpoints
- **[Quick Start Guide](QUICKSTART.md)** - Get started in 5 minutes
- **[Contributing Guide](CONTRIBUTING.md)** - How to add features and contribute
- **[Project Summary](PROJECT_SUMMARY.md)** - Architecture and design decisions

## Development

```bash
# Install dependencies
npm install

# Build
npm run build

# Watch mode
npm run watch

# Clean
npm run clean
```

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT

## Credits

This library provides ReScript bindings for [misskey-js](https://github.com/misskey-dev/misskey/tree/develop/packages/misskey-js), developed by the Misskey team. Misskey is a decentralized social platform that's part of the Fediverse.
