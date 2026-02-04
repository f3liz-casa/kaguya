// Notes module - Major API for note CRUD operations
// Provides simple, direct access to common note operations

open MisskeyJS_Common

// module API_Bindings = MisskeyJS_API_Bindings // Removed - no longer needed
module Client = MisskeyJS_Client

// Visibility type
type visibility = [#public | #home | #followers | #specified]

// Reaction acceptance type
type reactionAcceptance = [
  | #likeOnly
  | #likeOnlyForRemote
  | #nonSensitiveOnly
  | #nonSensitiveOnlyForLocalLikeOnlyForRemote
]

// Poll parameters
type poll = {
  choices: array<string>,
  multiple?: bool,
  expiresAt?: int,
  expiredAfter?: int,
}

// Internal: Convert visibility to string
let visibilityToString = (vis: visibility): string =>
  switch vis {
  | #public => "public"
  | #home => "home"
  | #followers => "followers"
  | #specified => "specified"
  }

// Internal: Convert reaction acceptance to string
let reactionAcceptanceToString = (ra: reactionAcceptance): string =>
  switch ra {
  | #likeOnly => "likeOnly"
  | #likeOnlyForRemote => "likeOnlyForRemote"
  | #nonSensitiveOnly => "nonSensitiveOnly"
  | #nonSensitiveOnlyForLocalLikeOnlyForRemote => "nonSensitiveOnlyForLocalLikeOnlyForRemote"
  }

// Internal: Error handler
let handleError = (error: exn): result<'a, [> #APIError(apiError) | #UnknownError(exn)]> => {
  switch isAPIError(error) {
  | Some(apiErr) => Error(#APIError(apiErr))
  | None => Error(#UnknownError(error))
  }
}

// ============================================================
// Create Note
// ============================================================

// Create a note - most common operation, simple API
let create = async (
  client: Client.t,
  ~text: option<string>=?,
  ~visibility: visibility=#public,
  ~cw: option<string>=?,
  ~localOnly: option<bool>=?,
  ~reactionAcceptance: option<reactionAcceptance>=?,
  ~fileIds: option<array<id>>=?,
  ~poll: option<poll>=?,
  ~replyId: option<id>=?,
  ~renoteId: option<id>=?,
  ~channelId: option<id>=?,
  ~visibleUserIds: option<array<id>>=?,
  (),
): result<JSON.t, [> #APIError(apiError) | #UnknownError(exn)]> => {
  let obj = Dict.make()

  text->Option.forEach(v => obj->Dict.set("text", JSON.Encode.string(v)))
  obj->Dict.set("visibility", JSON.Encode.string(visibilityToString(visibility)))
  cw->Option.forEach(v => obj->Dict.set("cw", JSON.Encode.string(v)))
  localOnly->Option.forEach(v => obj->Dict.set("localOnly", JSON.Encode.bool(v)))
  reactionAcceptance->Option.forEach(v =>
    obj->Dict.set("reactionAcceptance", JSON.Encode.string(reactionAcceptanceToString(v)))
  )
  fileIds->Option.forEach(arr =>
    obj->Dict.set("fileIds", JSON.Encode.array(arr->Array.map(JSON.Encode.string)))
  )
  poll->Option.forEach(p => {
    let pollObj = Dict.make()
    pollObj->Dict.set("choices", JSON.Encode.array(p.choices->Array.map(JSON.Encode.string)))
    p.multiple->Option.forEach(v => pollObj->Dict.set("multiple", JSON.Encode.bool(v)))
    p.expiresAt->Option.forEach(v => pollObj->Dict.set("expiresAt", JSON.Encode.int(v)))
    p.expiredAfter->Option.forEach(v => pollObj->Dict.set("expiredAfter", JSON.Encode.int(v)))
    obj->Dict.set("poll", JSON.Encode.object(pollObj))
  })
  replyId->Option.forEach(v => obj->Dict.set("replyId", JSON.Encode.string(v)))
  renoteId->Option.forEach(v => obj->Dict.set("renoteId", JSON.Encode.string(v)))
  channelId->Option.forEach(v => obj->Dict.set("channelId", JSON.Encode.string(v)))
  visibleUserIds->Option.forEach(arr =>
    obj->Dict.set("visibleUserIds", JSON.Encode.array(arr->Array.map(JSON.Encode.string)))
  )

  try {
    let result = await Client.request(
      client,
      ~endpoint="notes/create",
      ~params=JSON.Encode.object(obj),
    )
    Ok(result)
  } catch {
  | error => handleError(error)
  }
}

// ============================================================
// Show Note
// ============================================================

// Get a note by ID
let show = async (client: Client.t, ~noteId: id): result<
  JSON.t,
  [> #APIError(apiError) | #UnknownError(exn)],
> => {
  try {
    let result = await Client.request(
      client,
      ~endpoint="notes/show",
      ~params=JSON.Encode.object(Dict.fromArray([("noteId", JSON.Encode.string(noteId))])),
    )
    Ok(result)
  } catch {
  | error => handleError(error)
  }
}

// ============================================================
// Delete Note
// ============================================================

// Delete a note
let delete = async (client: Client.t, ~noteId: id): result<
  unit,
  [> #APIError(apiError) | #UnknownError(exn)],
> => {
  try {
    let _ = await Client.request(
      client,
      ~endpoint="notes/delete",
      ~params=JSON.Encode.object(Dict.fromArray([("noteId", JSON.Encode.string(noteId))])),
    )
    Ok()
  } catch {
  | error => handleError(error)
  }
}

// ============================================================
// Reactions
// ============================================================

// Add reaction to a note
let react = async (client: Client.t, ~noteId: id, ~reaction: string): result<
  unit,
  [> #APIError(apiError) | #UnknownError(exn)],
> => {
  try {
    let _ = await Client.request(
      client,
      ~endpoint="notes/reactions/create",
      ~params=JSON.Encode.object(
        Dict.fromArray([
          ("noteId", JSON.Encode.string(noteId)),
          ("reaction", JSON.Encode.string(reaction)),
        ]),
      ),
    )
    Ok()
  } catch {
  | error => handleError(error)
  }
}

// Remove reaction from a note
let unreact = async (client: Client.t, ~noteId: id): result<
  unit,
  [> #APIError(apiError) | #UnknownError(exn)],
> => {
  try {
    let _ = await Client.request(
      client,
      ~endpoint="notes/reactions/delete",
      ~params=JSON.Encode.object(Dict.fromArray([("noteId", JSON.Encode.string(noteId))])),
    )
    Ok()
  } catch {
  | error => handleError(error)
  }
}
