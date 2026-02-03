# Quick Start Guide

Get up and running with rescript-misskey in 5 minutes!

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

## Your First Request

```rescript
open MisskeyJS

// Create an API client
let api = API.make(
  ~origin="https://misskey.example.com",
  ~credential=Some("your-access-token"),
  ()
)

// Get server info
let getServerInfo = async () => {
  let result = await api->API.Meta.get(~detail=true, ())
  
  switch result {
  | Ok(meta) => Console.log("Server:", meta)
  | Error(#APIError(err)) => Console.log("Error:", err.message)
  | Error(#UnknownError(_)) => Console.log("Unknown error")
  }
}

// Call it
getServerInfo()->ignore
```

## Post a Note

```rescript
let postNote = async () => {
  let result = await api->API.Notes.create(~params={
    text: Some("Hello, Misskey! 🎉"),
    visibility: Some(#public),
  })
  
  switch result {
  | Ok(response) => Console.log("Posted!", response)
  | Error(#APIError(err)) => Console.log("Failed:", err.message)
  | Error(#UnknownError(_)) => Console.log("Unknown error")
  }
}

postNote()->ignore
```

## Listen to Timeline

```rescript
// Create a stream
let stream = Stream.make(
  ~origin="https://misskey.example.com",
  ~user=Some({token: "your-access-token"}),
  ()
)

// Connect to home timeline
let home = stream->Stream.HomeTimeline.use(
  ~params=Some({withRenotes: Some(true)}),
  ()
)

// Listen for new notes
home->Stream.HomeTimeline.onNote(note => {
  Console.log("New note:", note)
})

// Remember to cleanup when done
// home->Stream.HomeTimeline.dispose
// stream->Stream.close
```

## Get Notifications

```rescript
let getNotifications = async () => {
  let result = await api->API.Notifications.get(
    ~params={
      limit: Some(10),
      markAsRead: Some(true),
    }
  )
  
  switch result {
  | Ok(notifs) => {
      Console.log(`You have ${notifs->Array.length->Int.toString} notifications`)
      notifs->Array.forEach(n => Console.log(n))
    }
  | Error(_) => Console.log("Failed to get notifications")
  }
}

getNotifications()->ignore
```

## Complete Example

```rescript
open MisskeyJS

let main = async () => {
  // Setup API client
  let api = API.make(
    ~origin="https://misskey.example.com",
    ~credential=Some("your-token"),
    ()
  )
  
  // Setup streaming
  let stream = Stream.make(
    ~origin="https://misskey.example.com",
    ~user=Some({token: "your-token"}),
    ()
  )
  
  // Listen to notifications
  let main = stream->Stream.Main.use
  main->Stream.Main.onNotification(notif => {
    Console.log("🔔 New notification!")
  })
  
  // Listen to home timeline
  let home = stream->Stream.HomeTimeline.use()
  home->Stream.HomeTimeline.onNote(note => {
    Console.log("📝 New note in timeline")
  })
  
  // Post a note
  let _ = await api->API.Notes.create(~params={
    text: Some("Hello from ReScript! 🚀"),
    visibility: Some(#public),
  })
  
  // Get your profile
  let meResult = await api->API.I.get
  switch meResult {
  | Ok(me) => Console.log("Logged in as:", me)
  | Error(_) => Console.log("Failed to get profile")
  }
  
  // Cleanup function
  () => {
    main->Stream.Main.dispose
    home->Stream.HomeTimeline.dispose
    stream->Stream.close
  }
}

// Run it
let cleanup = main()->Promise.thenResolve(f => f)
```

## Getting Your Access Token

You need an access token to authenticate. There are two ways:

### Option 1: From Misskey Settings (Recommended for testing)

1. Go to your Misskey instance
2. Settings → API
3. Generate a new access token
4. Select the permissions you need
5. Copy the token

### Option 2: OAuth Flow (For production apps)

```rescript
// 1. Create your app (do this once)
let appResult = await api->API.request(
  ~endpoint="app/create",
  ~params=JSON.Encode.object([
    ("name", JSON.Encode.string("My App")),
    ("description", JSON.Encode.string("My cool app")),
    ("permission", JSON.Encode.array(permissions)),
  ]),
  ()
)

// 2. Generate auth session
// 3. Redirect user to authorization URL
// 4. Exchange session for token
// See full OAuth example in docs/
```

## Common Patterns

### Error Handling

```rescript
let result = await api->API.Notes.create(~params={...})

switch result {
| Ok(note) => {
    // Success!
    note
  }
| Error(#APIError({code, message})) => {
    // API returned an error
    Console.log2("API Error:", code)
    Console.log2("Message:", message)
  }
| Error(#UnknownError(exn)) => {
    // Network error or other exception
    Console.error("Unknown error:", exn)
  }
}
```

### Working with Visibility

```rescript
let note = await api->API.Notes.create(~params={
  text: Some("Hello!"),
  visibility: Some(#public),    // or #home, #followers, #specified
})
```

### Parsing User Mentions

```rescript
let acct = Acct.parse("@user@instance.com")
// => {username: "user", host: Some("instance.com")}

let displayName = acct->Acct.getDisplayName
// => "user@instance.com"
```

## Next Steps

- 📖 Read the [full API documentation](docs/API.md)
- 💡 Check out [more examples](examples/)
- 🤝 Learn how to [contribute](CONTRIBUTING.md)
- 🐛 Report issues on GitHub

## Common Issues

### "Module not found: misskey-js"
```bash
npm install misskey-js
```

### "Type error: bs-dependencies"
Make sure `rescript-misskey` is in your `bsconfig.json`:
```json
{
  "bs-dependencies": ["rescript-misskey"]
}
```

### WebSocket connection fails
Check that:
- Your Misskey instance supports WebSockets
- The origin URL is correct (include `https://`)
- Your access token is valid

## Need Help?

- Check the [API documentation](docs/API.md)
- Look at [examples](examples/)
- Open an issue on GitHub
- Join the Misskey community

Happy coding! 🎉
