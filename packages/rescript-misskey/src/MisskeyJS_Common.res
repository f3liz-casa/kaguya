// Common types used across the library

type id = string
type dateString = string

// Web API types
module Blob = {
  type t
}

// Emoji representation in text
type emoji = {
  name: string,
  url: string,
}

// User online status
type onlineStatus = [#online | #active | #offline | #unknown]

// Note visibility levels
type visibility = [#public | #home | #followers | #specified]

// Notification types
type notificationType = [
  | #note
  | #follow
  | #mention
  | #reply
  | #renote
  | #quote
  | #reaction
  | #pollEnded
  | #scheduledNotePosted
  | #scheduledNotePostFailed
  | #receiveFollowRequest
  | #followRequestAccepted
  | #app
  | #roleAssigned
  | #chatRoomInvitationReceived
  | #achievementEarned
  | #exportCompleted
  | #test
  | #login
  | #createToken
]

// Following/Followers visibility
type followVisibility = [#public | #followers | #\"private"]

// Muted note reasons
type mutedNoteReason = [#word | #manual | #spam | #other]

// API Error type
type apiError = {
  id: string,
  code: string,
  message: string,
  kind: [#client | #server],
  info: Dict.t<JSON.t>,
}

// Check if an error is an API error
@module("misskey-js/api")
external isAPIError: 'a => bool = "isAPIError"

let isAPIError = (error: exn): option<apiError> => {
  if isAPIError(error) {
    Some(error->Obj.magic)
  } else {
    None
  }
}

// Check if an API error is a permission denied (403) error
let isPermissionDenied = (error: apiError): bool => {
  // Check common permission denied error codes
  let code = error.code->String.toLowerCase
  code == "permission_denied" || 
  code == "no_such_permission" || 
  code == "access_denied" ||
  code == "insufficient_permissions" ||
  code == "forbidden"
}

