// SPDX-License-Identifier: MPL-2.0
// SharedTypes.res - Types shared across components

// ============================================================
// Reaction Types
// ============================================================

// Reaction acceptance policy for notes
// Determines what types of reactions a note can receive
type reactionAcceptance = [
  | #likeOnly // Only accepts "like" (❤️) reactions
  | #likeOnlyForRemote // Local can use any, remote only likes
  | #nonSensitiveOnly // Only non-sensitive reactions allowed
  | #nonSensitiveOnlyForLocalLikeOnlyForRemote
] // Complex policy

// Convert string to reactionAcceptance type
let reactionAcceptanceFromString = (str: string): option<reactionAcceptance> => {
  switch str {
  | "likeOnly" => Some(#likeOnly)
  | "likeOnlyForRemote" => Some(#likeOnlyForRemote)
  | "nonSensitiveOnly" => Some(#nonSensitiveOnly)
  | "nonSensitiveOnlyForLocalLikeOnlyForRemote" => Some(#nonSensitiveOnlyForLocalLikeOnlyForRemote)
  | _ => None
  }
}

// Convert reactionAcceptance to string
let reactionAcceptanceToString = (acceptance: reactionAcceptance): string => {
  switch acceptance {
  | #likeOnly => "likeOnly"
  | #likeOnlyForRemote => "likeOnlyForRemote"
  | #nonSensitiveOnly => "nonSensitiveOnly"
  | #nonSensitiveOnlyForLocalLikeOnlyForRemote => "nonSensitiveOnlyForLocalLikeOnlyForRemote"
  }
}
