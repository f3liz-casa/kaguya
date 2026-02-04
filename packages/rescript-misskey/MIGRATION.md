# Migration Guide

## Migrating from MisskeyJS API to Misskey API

The old `MisskeyJS` API has been **deprecated** in favor of a simpler, more intuitive `Misskey` API. This guide will help you migrate your code.

> 💡 **Note**: Use qualified names (`Misskey.connect`, `Misskey.Notes`) instead of `open Misskey` to avoid naming conflicts with other modules.

### Why Migrate?

The new `Misskey` API is:
- ✨ **Simpler**: 50% less code for common operations
- 🎯 **More discoverable**: Everything accessible through autocompletion
- 🧹 **Cleaner**: Consistent naming and patterns
- 📦 **Better tree-shaking**: Smaller bundle sizes

### Timeline

- **Now**: Old API is deprecated but still works
- **Future (v1.0)**: Old API will be removed in a major version bump

You should migrate at your convenience, but we recommend doing so sooner rather than later.

---

## Quick Comparison

### Connecting to a Server

```rescript
// OLD (deprecated)
open MisskeyJS
let client = Client.make(
  ~origin="https://misskey.io",
  ~credential="your-token",
  ()
)

// NEW (recommended) - Note: No "open" needed
let client = Misskey.connect("https://misskey.io", ~token="your-token")
```

### Posting a Note

```rescript
// OLD (deprecated)
open MisskeyJS
let result = await client->Notes.create(
  ~text="Hello!",
  ~visibility=Some(#public),
  ()
)

// NEW (recommended)
let result = await client->Misskey.Notes.create("Hello!", ~visibility=#public, ())
```

### Reading Timeline

```rescript
// OLD (deprecated)
open MisskeyJS
let result = await client->Timeline.fetch(
  ~type_=#home,
  ~params={limit: Some(20)},
  ()
)

// NEW (recommended)
open Misskey
let result = await client->Notes.timeline(#home, ~limit=20, ())
```

### Real-time Streaming

```rescript
// OLD (deprecated)
open MisskeyJS
let timeline = client
  ->Timeline.subscribe(~type_=#home, ())
  ->Timeline.onNote(note => Console.log(note))

// Cleanup
timeline->Timeline.dispose

// NEW (recommended)
open Misskey
let sub = client->Stream.timeline(#home, note => {
  Console.log(note)
})

// Cleanup
sub.dispose()
```

---

## Complete Migration Examples

### Example 1: Simple Note Posting

#### Before
```rescript
open MisskeyJS

let postNote = async () => {
  let client = Client.make(
    ~origin="https://misskey.io",
    ~credential="token",
    ()
  )
  
  let result = await client->Notes.create(
    ~text="Hello, world!",
    ~visibility=Some(#public),
    ()
  )
  
  switch result {
  | Ok(note) => Console.log(note)
  | Error(#APIError(err)) => Console.error(err.message)
  | Error(#UnknownError(_)) => Console.error("Unknown error")
  }
}
```

#### After
```rescript
open Misskey

let postNote = async () => {
  let client = connect("https://misskey.io", ~token="token")
  
  let result = await client->Notes.create("Hello, world!", ())
  
  switch result {
  | Ok(note) => Console.log(note)
  | Error(msg) => Console.error(msg)
  }
}
```

**Changes**:
- `Client.make()` → `connect()`
- Simpler parameters (no `Some()` wrapping)
- Simpler error type (just `string` instead of variant)

---

### Example 2: Timeline Streaming

#### Before
```rescript
open MisskeyJS

let streamTimeline = () => {
  let client = Client.make(~origin="https://misskey.io", ~credential="token", ())
  
  client->Client.onConnected(() => {
    Console.log("Connected!")
  })
  
  let timeline = client
    ->Timeline.subscribe(~type_=#home, ())
    ->Timeline.onNote(note => {
      Console.log(note)
    })
  
  // Cleanup
  () => {
    timeline->Timeline.dispose
    client->Client.close
  }
}
```

#### After
```rescript
open Misskey

let streamTimeline = () => {
  let client = connect("https://misskey.io", ~token="token")
  
  client->Stream.onConnected(() => {
    Console.log("Connected!")
  })
  
  let sub = client->Stream.timeline(#home, note => {
    Console.log(note)
  })
  
  // Cleanup
  () => {
    sub.dispose()
    Stream.close(client)
  }
}
```

**Changes**:
- `Timeline.subscribe()` → `Stream.timeline()`
- Event handler passed directly as parameter
- Simpler subscription object with `dispose()` method

---

### Example 3: Multiple Timelines

#### Before
```rescript
open MisskeyJS

let streamMultiple = () => {
  let client = Client.make(~origin="https://misskey.io", ~credential="token", ())
  
  let home = client
    ->Timeline.subscribe(~type_=#home, ())
    ->Timeline.onNote(note => Console.log2("Home:", note))
  
  let local = client
    ->Timeline.subscribe(~type_=#local, ())
    ->Timeline.onNote(note => Console.log2("Local:", note))
  
  let notifs = client
    ->Notifications.subscribe
    ->Notifications.onNotification(n => Console.log2("Notif:", n))
  
  () => {
    home->Timeline.dispose
    local->Timeline.dispose
    notifs->Notifications.dispose
  }
}
```

#### After
```rescript
open Misskey

let streamMultiple = () => {
  let client = connect("https://misskey.io", ~token="token")
  
  let home = client->Stream.timeline(#home, note => {
    Console.log2("Home:", note)
  })
  
  let local = client->Stream.timeline(#local, note => {
    Console.log2("Local:", note)
  })
  
  let notifs = client->Stream.notifications(n => {
    Console.log2("Notif:", n)
  })
  
  () => {
    home.dispose()
    local.dispose()
    notifs.dispose()
  }
}
```

**Changes**:
- All subscriptions use same pattern
- Event handlers inline, no chaining needed
- Consistent `dispose()` method

---

## API Mapping Reference

### Connection

| Old API | New API |
|---------|---------|
| `MisskeyJS.Client.make(~origin, ~credential, ())` | `Misskey.connect(origin, ~token)` |
| `Client.close(client)` | `Stream.close(client)` |

### Notes

| Old API | New API |
|---------|---------|
| `client->Notes.create(~text, ~visibility, ())` | `client->Notes.create(text, ~visibility, ())` |
| `client->Notes.delete(~noteId)` | `client->Notes.delete(noteId)` |
| `client->Notes.react(~noteId, ~reaction)` | `client->Notes.react(noteId, reaction)` |

### Timeline

| Old API | New API |
|---------|---------|
| `client->Timeline.fetch(~type_, ~params, ())` | `client->Notes.timeline(type_, ~limit, ())` |
| `client->Timeline.subscribe(~type_, ())->Timeline.onNote(handler)` | `client->Stream.timeline(type_, handler)` |

### Streaming

| Old API | New API |
|---------|---------|
| `client->Timeline.subscribe()->Timeline.onNote()` | `client->Stream.timeline(type_, onNote)` |
| `client->Notifications.subscribe->Notifications.onNotification()` | `client->Stream.notifications(onNotification)` |
| `subscription->Timeline.dispose` | `subscription.dispose()` |

### Connection Events

| Old API | New API |
|---------|---------|
| `client->Client.onConnected(callback)` | `client->Stream.onConnected(callback)` |
| `client->Client.onDisconnected(callback)` | `client->Stream.onDisconnected(callback)` |

---

## Error Handling Changes

### Old API (Complex)
```rescript
switch result {
| Ok(data) => // handle success
| Error(#APIError(err)) => Console.error(err.message)
| Error(#UnknownError(exn)) => Console.error("Unknown")
}
```

### New API (Simple)
```rescript
switch result {
| Ok(data) => // handle success
| Error(msg) => Console.error(msg)
}
```

The new API uses simple `result<'a, string>` types instead of complex error variants.

---

## Step-by-Step Migration Process

### 1. Update Imports
```rescript
// Change this:
open MisskeyJS

// To this:
open Misskey
```

### 2. Update Client Creation
```rescript
// Change this:
let client = Client.make(~origin, ~credential, ())

// To this:
let client = connect(origin, ~token=credential)
```

### 3. Update API Calls
- Remove `Some()` wrapping from optional parameters
- Move required parameters to positional (non-labeled)
- Keep optional parameters as labeled with `~`

### 4. Update Streaming
- Change `Timeline.subscribe()->Timeline.onNote()` to `Stream.timeline(type_, handler)`
- Change `subscription->Timeline.dispose` to `subscription.dispose()`

### 5. Simplify Error Handling
- Change complex error variants to simple string errors
- Remove pattern matching on error types if not needed

### 6. Test
- Ensure your application still compiles
- Test all API calls and streaming functionality
- Verify error handling works as expected

---

## Need Help?

- Check `examples/NewAPIExample.res` for a complete example
- See `examples/QuickStart.res` for a quick reference
- Compare with old examples (marked with deprecation notices)

---

## Benefits After Migration

After migrating, you'll enjoy:

1. **Less Code**: 30-50% reduction in boilerplate
2. **Better Autocompletion**: More discoverable API
3. **Cleaner Error Handling**: Simpler result types
4. **Consistent Patterns**: Everything follows the same style
5. **Future-Proof**: New features will only be added to the new API

---

## Questions?

If you have questions or need help migrating, please:
- Open an issue on GitHub
- Check the examples directory
- Read the updated README

The old API will continue to work for now, so you can migrate at your own pace.
