// Me module - Major API for current user operations
// Provides simple, direct access to authenticated user operations

open MisskeyJS_Common

module API_Bindings = MisskeyJS_API_Bindings
module Client = MisskeyJS_Client

// Internal: Error handler
let handleError = (error: exn): result<'a, [> #APIError(apiError) | #UnknownError(exn)]> => {
  switch isAPIError(error) {
  | Some(apiErr) => Error(#APIError(apiErr))
  | None => Error(#UnknownError(error))
  }
}

// ============================================================
// Get Current User
// ============================================================

// Get the authenticated user's info
let get = async (
  client: Client.t,
): result<JSON.t, [> #APIError(apiError) | #UnknownError(exn)]> => {
  try {
    let result = await Client.request(
      client,
      ~endpoint="i",
    )
    Ok(result)
  } catch {
  | error => handleError(error)
  }
}

// ============================================================
// Update Profile
// ============================================================

// Field type for profile fields
type field = {
  name: string,
  value: string,
}

// Update the authenticated user's profile
let update = async (
  client: Client.t,
  ~name: option<string>=?,
  ~description: option<string>=?,
  ~lang: option<string>=?,
  ~location: option<string>=?,
  ~birthday: option<string>=?,
  ~avatarId: option<id>=?,
  ~bannerId: option<id>=?,
  ~fields: option<array<field>>=?,
  ~isLocked: option<bool>=?,
  ~isExplorable: option<bool>=?,
  ~hideOnlineStatus: option<bool>=?,
  ~publicReactions: option<bool>=?,
  ~carefulBot: option<bool>=?,
  ~autoAcceptFollowed: option<bool>=?,
  ~noCrawle: option<bool>=?,
  ~preventAiLearning: option<bool>=?,
  ~isBot: option<bool>=?,
  ~isCat: option<bool>=?,
  ~injectFeaturedNote: option<bool>=?,
  ~receiveAnnouncementEmail: option<bool>=?,
  ~alwaysMarkNsfw: option<bool>=?,
  ~autoSensitive: option<bool>=?,
  ~ffVisibility: option<[#public | #followers | #\"private"]>=?,
  (),
): result<JSON.t, [> #APIError(apiError) | #UnknownError(exn)]> => {
  let obj = Dict.make()
  
  name->Option.forEach(v => obj->Dict.set("name", JSON.Encode.string(v)))
  description->Option.forEach(v => obj->Dict.set("description", JSON.Encode.string(v)))
  lang->Option.forEach(v => obj->Dict.set("lang", JSON.Encode.string(v)))
  location->Option.forEach(v => obj->Dict.set("location", JSON.Encode.string(v)))
  birthday->Option.forEach(v => obj->Dict.set("birthday", JSON.Encode.string(v)))
  avatarId->Option.forEach(v => obj->Dict.set("avatarId", JSON.Encode.string(v)))
  bannerId->Option.forEach(v => obj->Dict.set("bannerId", JSON.Encode.string(v)))
  fields->Option.forEach(arr => {
    let encoded = arr->Array.map(f => {
      JSON.Encode.object(Dict.fromArray([
        ("name", JSON.Encode.string(f.name)),
        ("value", JSON.Encode.string(f.value)),
      ]))
    })
    obj->Dict.set("fields", JSON.Encode.array(encoded))
  })
  isLocked->Option.forEach(v => obj->Dict.set("isLocked", JSON.Encode.bool(v)))
  isExplorable->Option.forEach(v => obj->Dict.set("isExplorable", JSON.Encode.bool(v)))
  hideOnlineStatus->Option.forEach(v => obj->Dict.set("hideOnlineStatus", JSON.Encode.bool(v)))
  publicReactions->Option.forEach(v => obj->Dict.set("publicReactions", JSON.Encode.bool(v)))
  carefulBot->Option.forEach(v => obj->Dict.set("carefulBot", JSON.Encode.bool(v)))
  autoAcceptFollowed->Option.forEach(v => obj->Dict.set("autoAcceptFollowed", JSON.Encode.bool(v)))
  noCrawle->Option.forEach(v => obj->Dict.set("noCrawle", JSON.Encode.bool(v)))
  preventAiLearning->Option.forEach(v => obj->Dict.set("preventAiLearning", JSON.Encode.bool(v)))
  isBot->Option.forEach(v => obj->Dict.set("isBot", JSON.Encode.bool(v)))
  isCat->Option.forEach(v => obj->Dict.set("isCat", JSON.Encode.bool(v)))
  injectFeaturedNote->Option.forEach(v => obj->Dict.set("injectFeaturedNote", JSON.Encode.bool(v)))
  receiveAnnouncementEmail->Option.forEach(v => obj->Dict.set("receiveAnnouncementEmail", JSON.Encode.bool(v)))
  alwaysMarkNsfw->Option.forEach(v => obj->Dict.set("alwaysMarkNsfw", JSON.Encode.bool(v)))
  autoSensitive->Option.forEach(v => obj->Dict.set("autoSensitive", JSON.Encode.bool(v)))
  ffVisibility->Option.forEach(v => {
    let str = switch v {
    | #public => "public"
    | #followers => "followers"
    | #\"private" => "private"
    }
    obj->Dict.set("ffVisibility", JSON.Encode.string(str))
  })
  
  try {
    let result = await API_Bindings.request(
      Client.apiClient(client),
      ~endpoint="i/update",
      ~params=JSON.Encode.object(obj),
    )
    Ok(result)
  } catch {
  | error => handleError(error)
  }
}
