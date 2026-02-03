// User entity types

open MisskeyJS_Common

// Profile field
type profileField = {
  name: string,
  value: string,
}

// Instance info (embedded in user objects)
type instance = {
  name: option<string>,
  softwareName: option<string>,
  softwareVersion: option<string>,
  iconUrl: option<string>,
  faviconUrl: option<string>,
  themeColor: option<string>,
}

// User Lite - minimal user information
type userLite = {
  id: id,
  username: string,
  host: option<string>,
  name: string,
  onlineStatus: onlineStatus,
  avatarUrl: string,
  avatarBlurhash: string,
  emojis: array<emoji>,
  instance: option<instance>,
}

// User Detailed - full user information
type userDetailed = {
  // Base user info
  id: id,
  username: string,
  host: option<string>,
  name: string,
  onlineStatus: onlineStatus,
  avatarUrl: string,
  avatarBlurhash: string,
  emojis: array<emoji>,
  instance: option<instance>,
  // Additional fields
  bannerUrl: option<string>,
  bannerBlurhash: option<string>,
  isLocked: bool,
  isSilenced: bool,
  isSuspended: bool,
  description: option<string>,
  location: option<string>,
  birthday: option<string>,
  lang: option<string>,
  fields: array<profileField>,
  verifiedLinks: array<string>,
  followersCount: int,
  followingCount: int,
  notesCount: int,
  pinnedNoteIds: array<id>,
  pinnedNotes: option<array<JSON.t>>, // Forward reference to Note
  pinnedPageId: option<id>,
  pinnedPage: option<JSON.t>,
  publicReactions: bool,
  ffVisibility: followVisibility,
  twoFactorEnabled: bool,
  usePasswordLessLogin: bool,
  securityKeys: bool,
  // Relation fields (may not be present)
  isFollowing: option<bool>,
  isFollowed: option<bool>,
  hasPendingFollowRequestFromYou: option<bool>,
  hasPendingFollowRequestToYou: option<bool>,
  isBlocking: option<bool>,
  isBlocked: option<bool>,
  isMuted: option<bool>,
  isRenoteMuted: option<bool>,
  notify: option<[#normal | #none]>,
  withReplies: option<bool>,
}

// MeDetailed - authenticated user with additional fields
type meDetailed = {
  // All userDetailed fields
  id: id,
  username: string,
  host: option<string>,
  name: string,
  onlineStatus: onlineStatus,
  avatarUrl: string,
  avatarBlurhash: string,
  emojis: array<emoji>,
  instance: option<instance>,
  bannerUrl: option<string>,
  bannerBlurhash: option<string>,
  isLocked: bool,
  isSilenced: bool,
  isSuspended: bool,
  description: option<string>,
  location: option<string>,
  birthday: option<string>,
  lang: option<string>,
  fields: array<profileField>,
  verifiedLinks: array<string>,
  followersCount: int,
  followingCount: int,
  notesCount: int,
  pinnedNoteIds: array<id>,
  pinnedNotes: option<array<JSON.t>>,
  pinnedPageId: option<id>,
  pinnedPage: option<JSON.t>,
  publicReactions: bool,
  ffVisibility: followVisibility,
  twoFactorEnabled: bool,
  usePasswordLessLogin: bool,
  securityKeys: bool,
  // Additional authenticated user fields
  avatarId: option<id>,
  bannerId: option<id>,
  isModerator: option<bool>,
  isAdmin: option<bool>,
  injectFeaturedNote: bool,
  receiveAnnouncementEmail: bool,
  alwaysMarkNsfw: bool,
  autoSensitive: bool,
  carefulBot: bool,
  autoAcceptFollowed: bool,
  noCrawle: bool,
  preventAiLearning: bool,
  isExplorable: bool,
  isDeleted: bool,
  twoFactorBackupCodesStock: option<[#full | #partial | #none]>,
  hideOnlineStatus: bool,
  hasUnreadSpecifiedNotes: bool,
  hasUnreadMentions: bool,
  hasUnreadAnnouncement: bool,
  hasUnreadAntenna: bool,
  hasUnreadChannel: bool,
  hasUnreadNotification: bool,
  hasPendingReceivedFollowRequest: bool,
  unreadNotificationsCount: int,
  mutedWords: array<array<string>>,
  mutedInstances: array<string>,
  notificationRecieveConfig: option<Dict.t<JSON.t>>,
  emailNotificationTypes: array<string>,
  achievements: array<JSON.t>,
  loggedInDays: int,
  policies: JSON.t,
}

// Union type for different user representations
type t =
  | @as("lite") Lite(userLite)
  | @as("detailed") Detailed(userDetailed)
  | @as("me") Me(meDetailed)
