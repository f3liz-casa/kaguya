// SPDX-License-Identifier: MPL-2.0

export type ReactionAcceptance =
  | 'likeOnly'
  | 'likeOnlyForRemote'
  | 'nonSensitiveOnly'
  | 'nonSensitiveOnlyForLocalLikeOnlyForRemote'

export function reactionAcceptanceFromString(str: string): ReactionAcceptance | undefined {
  switch (str) {
    case 'likeOnly': return 'likeOnly'
    case 'likeOnlyForRemote': return 'likeOnlyForRemote'
    case 'nonSensitiveOnly': return 'nonSensitiveOnly'
    case 'nonSensitiveOnlyForLocalLikeOnlyForRemote': return 'nonSensitiveOnlyForLocalLikeOnlyForRemote'
    default: return undefined
  }
}
