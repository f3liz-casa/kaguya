# rescript-misskey

**Pure ReScript** Misskey API client with a **clean, intuitive API** - discoverable through autocompletion!

> **Status**: ✅ Complete native ReScript implementation • Zero dependencies • Ultra-simple API

> ⚠️ **API Change Notice**: The old `MisskeyJS` API is deprecated. Use the new `Misskey` API shown below. See [MIGRATION.md](MIGRATION.md) for the migration guide.

## Why rescript-misskey?

✨ **Discoverable**: Just type and let autocompletion guide you  
🎯 **Simple**: Common operations are 1-2 lines  
🔒 **Type-safe**: Full ReScript type checking  
📦 **Zero dependencies**: No misskey-js required  
⚡ **Fast**: Native WebSocket implementation  
🧩 **Flexible**: Optional parameters for advanced use

## Quick Start

```rescript
// Connect
let client = Misskey.connect("https://misskey.io", ~token="your-token")

// Post a note
await client->Misskey.Notes.create("Hello, Misskey!", ())

// Stream timeline
let sub = client->Misskey.Stream.timeline(#home, note => {
  Console.log2("New note!", note)
})

// Cleanup
sub.dispose()
```

**That's it!** Everything else you discover through autocompletion.

> 💡 **Tip**: Use qualified names (`Misskey.connect`, `Misskey.Notes`) instead of `open Misskey` to avoid naming conflicts.

## Installation

```bash
npm install rescript-misskey
```

Add to your `rescript.json`:

```json
{
  "bs-dependencies": ["rescript-misskey"]
}
```

## Examples

### Post Notes

```rescript
// Simple post
await client->Misskey.Notes.create("Hello!", ())

// With options
await client->Misskey.Notes.create(
  "Private post",
  ~visibility=#followers,
  ~cw="Content warning",
  ()
)

// Reply to a note
await client->Misskey.Notes.create(
  "Great post!",
  ~replyId="note-id",
  ()
)

// React to a note
await client->Misskey.Notes.react("note-id", "👍")
```

### Read Timelines

```rescript
// Get home timeline
let result = await client->Misskey.Notes.timeline(#home, ~limit=20, ())

switch result {
| Ok(notes) => Console.log(notes)
| Error(msg) => Console.error(msg)
}

// Other timelines: #local, #global, #hybrid
await client->Misskey.Notes.timeline(#local, ())
```

### Real-time Streaming

```rescript
// Stream timeline
let homeSub = client->Misskey.Stream.timeline(#home, note => {
  Console.log2("New note!", note)
})

// Stream notifications
let notifSub = client->Misskey.Stream.notifications(notif => {
  Console.log2("Notification!", notif)
})

// Connection events
client->Misskey.Stream.onConnected(() => Console.log("Connected!"))
client->Misskey.Stream.onDisconnected(() => Console.log("Disconnected!"))

// Cleanup
homeSub.dispose()
notifSub.dispose()
```

## API Overview

### Connection

```rescript
// Public instance
let client = Misskey.connect("https://misskey.io")

// Authenticated
let myClient = Misskey.connect("https://misskey.io", ~token="abc123")
```

### Notes API

```rescript
client->Misskey.Notes.create(text, ~visibility?, ~cw?, ~localOnly?, ~replyId?, ~renoteId?, ())
client->Misskey.Notes.delete(noteId)
client->Misskey.Notes.timeline(#home | #local | #global | #hybrid, ~limit?, ~sinceId?, ~untilId?, ())
client->Misskey.Notes.react(noteId, reaction)
```

### Stream API

```rescript
client->Misskey.Stream.timeline(type_, onNote) // Returns {dispose: unit => unit}
client->Misskey.Stream.notifications(onNotification)
client->Misskey.Stream.onConnected(callback)
client->Misskey.Stream.onDisconnected(callback)
Misskey.Stream.close(client)
```

## Discover Through Autocompletion

The API is designed to be self-documenting. Just start typing:

1. Type: `client->Misskey.Notes.`
2. See: `create`, `delete`, `timeline`, `react`
3. Pick one and see clear parameters with documentation
4. Done!

Every function has:
- Clear, descriptive names
- Inline documentation
- Sensible defaults
- Type-safe parameters

## Architecture

This is a **pure ReScript implementation**:

- 🎯 Native WebSocket bindings - No JavaScript dependencies
- 📦 OpenAPI-generated types - Auto-generated from official Misskey spec
- 🔒 Full type safety - ReScript all the way down
- ⚡ Better tree-shaking - Smaller bundle sizes

## Examples

Check out the [examples/](examples/) directory:

- **[QuickStart.res](examples/QuickStart.res)** - Get started in 60 seconds
- **[NewAPIExample.res](examples/NewAPIExample.res)** - Complete API tour
- **[WebSocketTestExample.res](examples/WebSocketTestExample.res)** - Test WebSocket connections

## Migrating from Old API

If you're using the old `MisskeyJS` API (with `MisskeyJS.Client.make`, etc.), it's time to migrate to the simpler `Misskey` API!

**Quick comparison:**
```rescript
// OLD (deprecated)
open MisskeyJS
let client = Client.make(~origin="https://misskey.io", ~credential="token", ())

// NEW (recommended)
let client = Misskey.connect("https://misskey.io", ~token="token")
```

**See the complete [Migration Guide](MIGRATION.md)** for:
- Step-by-step migration instructions
- API mapping reference
- Before/after examples
- Error handling changes

The old API still works but is deprecated and will be removed in v1.0.

## Documentation

- [API Reference](docs/API.md) - Complete API documentation
- [Migration Guide](MIGRATION.md) - Migrating from old API

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT

## Credits

Pure ReScript implementation of the Misskey API client. Built from the ground up for simplicity and type safety.

Misskey is a decentralized social platform - part of the Fediverse. Learn more at [misskey-hub.net](https://misskey-hub.net/).
