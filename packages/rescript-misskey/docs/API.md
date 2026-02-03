# API Documentation

Complete API reference for rescript-misskey.

## Table of Contents

- [Installation](#installation)
- [API Client](#api-client)
- [Streaming](#streaming)
- [Types](#types)
- [Utilities](#utilities)

## Installation

```bash
npm install rescript-misskey misskey-js
```

Add to `bsconfig.json`:

```json
{
  "bs-dependencies": ["rescript-misskey"]
}
```

## API Client

### Creating a Client

```rescript
open MisskeyJS

let api = API.make(
  ~origin="https://misskey.example",
  ~credential=Some("your-token"),
  ()
)
```

### Server Meta

```rescript
// Get server metadata
let meta = await api->API.Meta.get(~detail=true, ())
```

### Current User (I)

```rescript
// Get current user info
let user = await api->API.I.get

// Update profile
let updated = await api->API.I.update(~params={
  name: Some("New Name"),
  description: Some("New bio"),
  isLocked: Some(true),
})
```

### Notes

```rescript
// Create a note
let note = await api->API.Notes.create(~params={
  text: Some("Hello, Misskey!"),
  visibility: Some(#public),
  localOnly: Some(false),
  cw: Some("Content warning"),
  fileIds: Some(["file-id-1", "file-id-2"]),
  poll: Some({
    choices: ["Option A", "Option B"],
    multiple: Some(false),
    expiresAt: Some(1234567890),
  }),
})

// Show a note
let note = await api->API.Notes.show(~noteId="note-id")

// Delete a note
let _ = await api->API.Notes.delete(~noteId="note-id")

// React to a note
let _ = await api->API.Notes.Reactions.create(
  ~noteId="note-id",
  ~reaction="👍"
)

// Remove reaction
let _ = await api->API.Notes.Reactions.delete(~noteId="note-id")

// Get home timeline
let notes = await api->API.Notes.timeline(~params={
  limit: Some(20),
  sinceId: Some("note-id"),
  withRenotes: Some(true),
})

// Get local timeline
let notes = await api->API.Notes.localTimeline(~params={
  limit: Some(20),
  withReplies: Some(true),
  withFiles: Some(false),
})

// Get global timeline
let notes = await api->API.Notes.globalTimeline(~params={
  limit: Some(20),
  withRenotes: Some(true),
})
```

### Users

```rescript
// Show user by ID
let user = await api->API.Users.show(
  ~params=UserId("user-id")
)

// Show user by username
let user = await api->API.Users.show(
  ~params=Username({
    username: "alice",
    host: Some("misskey.example")
  })
)

// Get user's notes
let notes = await api->API.Users.notes(~params={
  userId: "user-id",
  limit: Some(20),
  includeReplies: Some(true),
})
```

### Following

```rescript
// Follow a user
let _ = await api->API.Following.create(~userId="user-id")

// Unfollow a user
let _ = await api->API.Following.delete(~userId="user-id")
```

### Notifications

```rescript
// Get notifications
let notifications = await api->API.Notifications.get(~params={
  limit: Some(10),
  markAsRead: Some(true),
  includeTypes: Some([#follow, #mention, #reply]),
})

// Mark all as read
let _ = await api->API.Notifications.markAllAsRead
```

### Drive

```rescript
// List files
let files = await api->API.Drive.files(~params={
  limit: Some(20),
  folderId: Some("folder-id"),
})

// Upload a file
let file = await api->API.Drive.createFile(~params={
  file: blob,
  name: Some("image.png"),
  comment: Some("My photo"),
  isSensitive: Some(false),
})

// Delete a file
let _ = await api->API.Drive.deleteFile(~fileId="file-id")

// Create a folder
let folder = await api->API.Drive.createFolder(
  ~name="My Folder",
  ~parentId=Some("parent-folder-id")
)
```

### Error Handling

All API methods return `Result.t` with typed errors:

```rescript
let result = await api->API.Notes.create(~params={
  text: Some("Hello!"),
})

switch result {
| Ok(note) => Console.log("Success!", note)
| Error(#APIError(err)) => {
    Console.log2("API Error:", err.code)
    Console.log2("Message:", err.message)
  }
| Error(#UnknownError(err)) => {
    Console.log("Unknown error:", err)
  }
}
```

## Streaming

### Creating a Stream

```rescript
open MisskeyJS

let stream = Stream.make(
  ~origin="https://misskey.example",
  ~user=Some({token: "your-token"}),
  ()
)
```

### Connection Events

```rescript
stream->Stream.onConnected(() => {
  Console.log("Connected!")
})

stream->Stream.onDisconnected(() => {
  Console.log("Disconnected!")
})
```

### Main Channel

Receives notifications and personal updates.

```rescript
let main = stream->Stream.Main.use

main->Stream.Main.onNotification(notif => {
  Console.log("New notification:", notif)
})

main->Stream.Main.onMention(note => {
  Console.log("Mentioned:", note)
})

main->Stream.Main.onReply(note => {
  Console.log("Reply:", note)
})

main->Stream.Main.onRenote(note => {
  Console.log("Renote:", note)
})

main->Stream.Main.onFollow(user => {
  Console.log("New follower:", user)
})

main->Stream.Main.onMeUpdated(user => {
  Console.log("Profile updated:", user)
})

// Cleanup when done
main->Stream.Main.dispose
```

### Timeline Channels

#### Home Timeline

```rescript
let home = stream->Stream.HomeTimeline.use(
  ~params=Some({
    withRenotes: Some(true),
    withFiles: Some(false),
  }),
  ()
)

home->Stream.HomeTimeline.onNote(note => {
  Console.log("Home timeline note:", note)
})

home->Stream.HomeTimeline.dispose
```

#### Local Timeline

```rescript
let local = stream->Stream.LocalTimeline.use(
  ~params=Some({
    withRenotes: Some(true),
    withReplies: Some(true),
    withFiles: Some(false),
  }),
  ()
)

local->Stream.LocalTimeline.onNote(note => {
  Console.log("Local timeline note:", note)
})

local->Stream.LocalTimeline.dispose
```

#### Global Timeline

```rescript
let global = stream->Stream.GlobalTimeline.use(
  ~params=Some({
    withRenotes: Some(true),
    withFiles: Some(false),
  }),
  ()
)

global->Stream.GlobalTimeline.onNote(note => {
  Console.log("Global timeline note:", note)
})

global->Stream.GlobalTimeline.dispose
```

#### Hybrid Timeline

```rescript
let hybrid = stream->Stream.HybridTimeline.use(
  ~params=Some({
    withRenotes: Some(true),
    withReplies: Some(true),
    withFiles: Some(false),
  }),
  ()
)

hybrid->Stream.HybridTimeline.onNote(note => {
  Console.log("Hybrid timeline note:", note)
})

hybrid->Stream.HybridTimeline.dispose
```

### Drive Channel

```rescript
let drive = stream->Stream.Drive.use

drive->Stream.Drive.onFileCreated(file => {
  Console.log("File created:", file)
})

drive->Stream.Drive.onFileDeleted(fileId => {
  Console.log("File deleted:", fileId)
})

drive->Stream.Drive.onFileUpdated(file => {
  Console.log("File updated:", file)
})

drive->Stream.Drive.onFolderCreated(folder => {
  Console.log("Folder created:", folder)
})

drive->Stream.Drive.dispose
```

### Server Stats Channel

```rescript
let stats = stream->Stream.ServerStats.use

stats->Stream.ServerStats.onStats(data => {
  Console.log("Server stats:", data)
})

stats->Stream.ServerStats.onStatsLog(log => {
  Console.log("Server stats log:", log)
})

// Request historical stats
stats->Stream.ServerStats.requestLog(~id="req-1", ~length=50)

stats->Stream.ServerStats.dispose
```

### Closing the Stream

```rescript
stream->Stream.close
```

## Types

### Common Types

```rescript
type id = string
type dateString = string

type visibility = [#public | #home | #followers | #specified]
type onlineStatus = [#online | #active | #offline | #unknown]
type followVisibility = [#public | #followers | #private]
```

### User Types

```rescript
type userLite = {
  id: id,
  username: string,
  host: option<string>,
  name: string,
  onlineStatus: onlineStatus,
  avatarUrl: string,
  // ... more fields
}

type userDetailed = {
  // All userLite fields plus:
  followersCount: int,
  followingCount: int,
  notesCount: int,
  isFollowing: option<bool>,
  isFollowed: option<bool>,
  // ... more fields
}

type meDetailed = {
  // All userDetailed fields plus:
  hasUnreadNotification: bool,
  unreadNotificationsCount: int,
  // ... more fields
}
```

### Note Types

```rescript
type note = {
  id: id,
  createdAt: dateString,
  userId: id,
  user: JSON.t,
  text: option<string>,
  cw: option<string>,
  visibility: visibility,
  reactions: Dict.t<int>,
  renoteCount: int,
  repliesCount: int,
  files: array<JSON.t>,
  poll: option<poll>,
  // ... more fields
}

// Check if note is pure renote
let isPure = MisskeyJS.Note.isPureRenote(note)
```

### Notification Types

```rescript
type notificationBody =
  | Note({note: JSON.t})
  | Follow({user: JSON.t})
  | Mention({user: JSON.t, note: JSON.t})
  | Reply({user: JSON.t, note: JSON.t})
  | Renote({user: JSON.t, note: JSON.t})
  | Reaction({user: JSON.t, note: JSON.t, reaction: string})
  // ... more variants
```

### Drive Types

```rescript
type driveFile = {
  id: id,
  name: string,
  type_: string,
  size: int,
  url: string,
  thumbnailUrl: option<string>,
  // ... more fields
}

type driveFolder = {
  id: id,
  name: string,
  parentId: option<id>,
  // ... more fields
}
```

## Utilities

### Acct (Account Identifiers)

```rescript
open MisskeyJS

// Parse account string
let acct = Acct.parse("user@example.com")
// => {username: "user", host: Some("example.com")}

// Create account
let acct = Acct.make(
  ~username="alice",
  ~host=Some("misskey.example"),
  ()
)

// Convert to string
let str = acct->Acct.toString
// => "alice@misskey.example"

// Check if local/remote
let isLocal = acct->Acct.isLocal
let isRemote = acct->Acct.isRemote

// Get display name
let display = acct->Acct.getDisplayName
```

### Constants

```rescript
open MisskeyJS.Constants

// Access raw constant arrays
notificationTypes // array<string>
noteVisibilities // array<string>
permissions // array<string>

// Work with typed enums
let notifType: NotificationType.t = #follow
let str = notifType->NotificationType.toString // "follow"
let parsed = NotificationType.fromString("mention") // Some(#mention)

let vis: Visibility.t = #public
let visStr = vis->Visibility.toString // "public"

// Nyaize text (cat mode)
let nya = nyaize("Hello, how are you?")
// => "Hello, how are you~?"
```

## Full Example

```rescript
open MisskeyJS

let main = async () => {
  // Create API client
  let api = API.make(
    ~origin="https://misskey.example",
    ~credential=Some("your-token"),
    ()
  )

  // Create stream
  let stream = Stream.make(
    ~origin="https://misskey.example",
    ~user=Some({token: "your-token"}),
    ()
  )

  // Listen to notifications
  let main = stream->Stream.Main.use
  main->Stream.Main.onNotification(notif => {
    Console.log("Notification:", notif)
  })

  // Listen to home timeline
  let home = stream->Stream.HomeTimeline.use()
  home->Stream.HomeTimeline.onNote(note => {
    Console.log("New note:", note)
  })

  // Create a note
  let result = await api->API.Notes.create(~params={
    text: Some("Hello from ReScript!"),
    visibility: Some(#public),
  })

  switch result {
  | Ok(note) => Console.log("Note created:", note)
  | Error(#APIError(err)) => Console.error(err.message)
  | Error(#UnknownError(_)) => Console.error("Unknown error")
  }

  // Cleanup
  let cleanup = () => {
    main->Stream.Main.dispose
    home->Stream.HomeTimeline.dispose
    stream->Stream.close
  }

  cleanup
}
```
