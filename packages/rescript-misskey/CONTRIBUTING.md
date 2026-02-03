# Contributing to rescript-misskey

Thank you for your interest in contributing to rescript-misskey! This guide will help you get started.

## Project Structure

```
rescript-misskey/
├── src/
│   ├── internal/               # Low-level FFI bindings
│   │   ├── MisskeyJS_API_Bindings.res
│   │   └── MisskeyJS_Stream_Bindings.res
│   ├── types/                  # Entity type definitions
│   │   ├── MisskeyJS_User.res
│   │   ├── MisskeyJS_Note.res
│   │   ├── MisskeyJS_Notification.res
│   │   └── MisskeyJS_Drive.res
│   ├── MisskeyJS_Common.res    # Common types and utilities
│   ├── MisskeyJS_API.res       # High-level API wrapper
│   ├── MisskeyJS_Stream.res    # High-level Streaming wrapper
│   ├── MisskeyJS_Acct.res      # Account utilities
│   ├── MisskeyJS_Constants.res # Constants and enums
│   └── MisskeyJS.res           # Main module with re-exports
├── examples/                    # Usage examples
│   ├── BasicAPIExample.res
│   ├── StreamingExample.res
│   ├── AcctExample.res
│   └── ConstantsExample.res
├── docs/                        # Documentation
│   └── API.md
├── package.json
├── bsconfig.json
└── README.md
```

## Architecture

This library follows a two-layer architecture similar to Rust's `-sys` pattern:

### Layer 1: Low-level Bindings (`internal/`)

- **Purpose**: Direct FFI bindings to misskey-js with minimal abstraction
- **Location**: `src/internal/*_Bindings.res`
- **Guidelines**:
  - Use `@module`, `@send`, `@get` external bindings
  - Keep types close to JavaScript
  - Minimal ReScript idioms
  - Use `JSON.t` for complex types

### Layer 2: High-level Wrappers (public API)

- **Purpose**: Idiomatic ReScript interfaces with type safety
- **Location**: `src/MisskeyJS_*.res` (except `_Bindings`)
- **Guidelines**:
  - Use `Result.t` for error handling
  - Use polymorphic variants for enums
  - Use labeled arguments
  - Provide helper functions
  - Add ReScript-friendly conveniences

## Development Setup

```bash
# Clone the repository
git clone https://github.com/your-username/rescript-misskey.git
cd rescript-misskey

# Install dependencies
npm install

# Build the project
npm run build

# Watch mode for development
npm run watch
```

## Adding New Features

### Adding a New API Endpoint

1. **Add low-level binding** in `src/internal/MisskeyJS_API_Bindings.res`:

```rescript
type myEndpointParams = {
  param1: string,
  param2?: int,
}

@send
external requestMyEndpoint: (
  t,
  @as("my/endpoint") _,
  ~params: myEndpointParams,
) => promise<JSON.t> = "request"
```

2. **Add high-level wrapper** in `src/MisskeyJS_API.res`:

```rescript
module MyFeature = {
  type params = {
    param1: string,
    param2?: int,
  }

  let get = async (client: t, ~params: params) => {
    try {
      let result = await Bindings.requestMyEndpoint(client, ~params)
      Ok(result)
    } catch {
    | error => handleError(error)
    }
  }
}
```

### Adding a New Streaming Channel

1. **Add low-level binding** in `src/internal/MisskeyJS_Stream_Bindings.res`:

```rescript
module MyChannel = {
  type events
  type receives

  type t = connection<events, receives>

  @send external onMyEvent: (t, @as("myEvent") _, JSON.t => unit) => unit = "on"
}
```

2. **Add high-level wrapper** in `src/MisskeyJS_Stream.res`:

```rescript
module MyChannel = {
  type t = Bindings.MyChannel.t

  type params = {
    param1?: bool,
  }

  let use = (stream: t, ~params: option<params>=?, ()) => {
    let jsonParams = params->Option.map(p => {
      JSON.Encode.object([
        ("param1", p.param1->Option.map(JSON.Encode.bool)->Option.getOr(JSON.Encode.null)),
      ])
    })
    Bindings.useChannel(~stream, ~channel="myChannel", ~params=?jsonParams, ())
    ->Obj.magic
  }

  let onMyEvent = (conn: t, callback: JSON.t => unit): unit => {
    Bindings.MyChannel.onMyEvent(conn, callback)
  }

  let dispose = Channel.dispose
}
```

### Adding Entity Types

Add new entity type definitions in `src/types/`:

```rescript
// src/types/MisskeyJS_MyEntity.res
open MisskeyJS_Common

type myEntity = {
  id: id,
  name: string,
  createdAt: dateString,
  // ... more fields
}

type t = myEntity
```

Then export it in `src/MisskeyJS.res`:

```rescript
module MyEntity = MisskeyJS_MyEntity
```

## Code Style Guidelines

### General

- Use 2 spaces for indentation
- Use meaningful variable names
- Add comments for complex logic
- Keep functions focused and small

### ReScript Specific

- Use `->` pipe operator for chaining
- Prefer `switch` over `if/else` for pattern matching
- Use labeled arguments for functions with multiple parameters
- Use `option` instead of `null`/`undefined`
- Use `result` for operations that can fail

### Example

```rescript
// Good
let getUserNotes = async (client: t, ~userId: string, ~limit: int=20, ()) => {
  let result = await client->API.Users.notes(~params={
    userId,
    limit: Some(limit),
  })

  switch result {
  | Ok(notes) => notes->Array.map(processNote)
  | Error(err) => []
  }
}

// Avoid
let getUserNotes = async (client, userId, limit) => {
  let result = await API.Users.notes(client, {userId: userId, limit: limit})
  if result.ok {
    result.data.map(processNote)
  } else {
    []
  }
}
```

## Testing

Currently, this library relies on the underlying misskey-js package's testing. When adding new features:

1. Test bindings manually with a real Misskey instance
2. Verify type safety compiles correctly
3. Test error handling paths

Future: We plan to add automated tests using a test Misskey instance.

## Documentation

When adding new features:

1. **Update API.md**: Add detailed documentation with examples
2. **Add examples**: Create or update example files in `examples/`
3. **Update README.md**: If adding major features

## Submitting Changes

1. **Fork** the repository
2. **Create a branch**: `git checkout -b feature/my-feature`
3. **Make changes**: Follow the guidelines above
4. **Build**: Ensure `npm run build` succeeds
5. **Commit**: Use clear commit messages
6. **Push**: `git push origin feature/my-feature`
7. **Create Pull Request**: Describe your changes

### Commit Message Format

```
type(scope): subject

body (optional)

footer (optional)
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

Example:
```
feat(api): add support for clips endpoints

- Add Clips.create binding
- Add Clips.delete binding
- Add Clips.addNote binding
- Update API documentation

Closes #123
```

## Questions?

- Open an issue for bugs or feature requests
- Start a discussion for questions
- Check existing issues and docs first

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
