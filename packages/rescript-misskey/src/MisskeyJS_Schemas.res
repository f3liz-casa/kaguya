// SPDX-License-Identifier: MPL-2.0
// MisskeyJS_Schemas.res - Validation schemas for Misskey API responses using Sury
//
// This module defines schemas for all Misskey entity types with full type inference.

// ============================================================
// Type definitions
// ============================================================

type emoji = {
  name: string,
  url: string,
  category: option<string>,
  aliases: option<array<string>>,
}

type instance = {
  name: option<string>,
  softwareName: option<string>,
  softwareVersion: option<string>,
  iconUrl: option<string>,
  faviconUrl: option<string>,
  themeColor: option<string>,
}

type profileField = {
  name: string,
  value: string,
}

type userLite = {
  id: string,
  username: string,
  host: option<string>,
  name: string,
  onlineStatus: string,
  avatarUrl: string,
  avatarBlurhash: string,
  emojis: array<emoji>,
  instance: option<instance>,
}

type userDetailed = {
  // Base user info
  id: string,
  username: string,
  host: option<string>,
  name: string,
  onlineStatus: string,
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
  pinnedNoteIds: array<string>,
  publicReactions: bool,
  ffVisibility: string,
  twoFactorEnabled: bool,
  usePasswordLessLogin: bool,
  securityKeys: bool,
  // Relation fields (optional)
  isFollowing: option<bool>,
  isFollowed: option<bool>,
  hasPendingFollowRequestFromYou: option<bool>,
  hasPendingFollowRequestToYou: option<bool>,
  isBlocking: option<bool>,
  isBlocked: option<bool>,
  isMuted: option<bool>,
  isRenoteMuted: option<bool>,
}

type driveFile = {
  id: string,
  createdAt: string,
  name: string,
  @as("type") type_: string,
  md5: string,
  size: float,
  isSensitive: bool,
  blurhash: option<string>,
  url: option<string>,
  thumbnailUrl: option<string>,
  comment: option<string>,
  folderId: option<string>,
  userId: option<string>,
}

type driveFolder = {
  id: string,
  createdAt: string,
  name: string,
  parentId: option<string>,
}

type pollChoice = {
  text: string,
  votes: int,
  isVoted: option<bool>,
}

type poll = {
  multiple: bool,
  expiresAt: option<string>,
  choices: array<pollChoice>,
}

type channel = {
  id: string,
  name: string,
}

type rec note = {
  id: string,
  createdAt: string,
  userId: string,
  user: userLite,
  text: option<string>,
  cw: option<string>,
  visibility: string,
  localOnly: option<bool>,
  reactionAcceptance: option<string>,
  renoteCount: int,
  repliesCount: int,
  reactionEmojis: array<emoji>,
  emojis: array<emoji>,
  fileIds: array<string>,
  files: array<driveFile>,
  replyId: option<string>,
  renoteId: option<string>,
  uri: option<string>,
  url: option<string>,
  channelId: option<string>,
  channel: option<channel>,
  poll: option<poll>,
}

type notification = {
  id: string,
  createdAt: string,
  @as("type") type_: string,
  userId: option<string>,
  user: option<userLite>,
  note: option<note>,
}

type meta = {
  maintainerName: option<string>,
  maintainerEmail: option<string>,
  version: string,
  name: option<string>,
  shortName: option<string>,
  uri: string,
  description: option<string>,
  langs: option<array<string>>,
  tosUrl: option<string>,
  repositoryUrl: string,
  feedbackUrl: string,
  disableRegistration: bool,
  emailRequiredForSignup: bool,
  enableHcaptcha: bool,
  enableRecaptcha: bool,
  enableTurnstile: bool,
  maxNoteTextLength: int,
  enableEmail: bool,
  enableServiceWorker: bool,
  emojis: array<emoji>,
}

// ============================================================
// Schema definitions
// ============================================================

// Emoji schema
let emojiSchema = S.object(s => {
  name: s.field("name", S.string),
  url: s.field("url", S.string),
  category: s.field("category", S.option(S.string)),
  aliases: s.field("aliases", S.option(S.array(S.string))),
})

// Instance schema
let instanceSchema = S.object(s => {
  name: s.field("name", S.option(S.string)),
  softwareName: s.field("softwareName", S.option(S.string)),
  softwareVersion: s.field("softwareVersion", S.option(S.string)),
  iconUrl: s.field("iconUrl", S.option(S.string)),
  faviconUrl: s.field("faviconUrl", S.option(S.string)),
  themeColor: s.field("themeColor", S.option(S.string)),
})

// Profile field schema
let profileFieldSchema = S.object(s => {
  name: s.field("name", S.string),
  value: s.field("value", S.string),
})

// Online status enum - simple strings for now
let onlineStatusSchema = S.union([
  S.literal("online"),
  S.literal("active"),
  S.literal("offline"),
  S.literal("unknown"),
])

// Follow visibility enum
let followVisibilitySchema = S.union([
  S.literal("public"),
  S.literal("followers"),
  S.literal("private"),
])

// User Lite schema
let userLiteSchema = S.object(s => {
  id: s.field("id", S.string),
  username: s.field("username", S.string),
  host: s.field("host", S.option(S.string)),
  name: s.field("name", S.string),
  onlineStatus: s.field("onlineStatus", onlineStatusSchema),
  avatarUrl: s.field("avatarUrl", S.string),
  avatarBlurhash: s.field("avatarBlurhash", S.string),
  emojis: s.field("emojis", S.array(emojiSchema)),
  instance: s.field("instance", S.option(instanceSchema)),
})

// User Detailed schema
let userDetailedSchema = S.object(s => {
  // Base user info
  id: s.field("id", S.string),
  username: s.field("username", S.string),
  host: s.field("host", S.option(S.string)),
  name: s.field("name", S.string),
  onlineStatus: s.field("onlineStatus", onlineStatusSchema),
  avatarUrl: s.field("avatarUrl", S.string),
  avatarBlurhash: s.field("avatarBlurhash", S.string),
  emojis: s.field("emojis", S.array(emojiSchema)),
  instance: s.field("instance", S.option(instanceSchema)),
  // Additional fields
  bannerUrl: s.field("bannerUrl", S.option(S.string)),
  bannerBlurhash: s.field("bannerBlurhash", S.option(S.string)),
  isLocked: s.field("isLocked", S.bool),
  isSilenced: s.field("isSilenced", S.bool),
  isSuspended: s.field("isSuspended", S.bool),
  description: s.field("description", S.option(S.string)),
  location: s.field("location", S.option(S.string)),
  birthday: s.field("birthday", S.option(S.string)),
  lang: s.field("lang", S.option(S.string)),
  fields: s.field("fields", S.array(profileFieldSchema)),
  verifiedLinks: s.field("verifiedLinks", S.array(S.string)),
  followersCount: s.field("followersCount", S.int),
  followingCount: s.field("followingCount", S.int),
  notesCount: s.field("notesCount", S.int),
  pinnedNoteIds: s.field("pinnedNoteIds", S.array(S.string)),
  publicReactions: s.field("publicReactions", S.bool),
  ffVisibility: s.field("ffVisibility", followVisibilitySchema),
  twoFactorEnabled: s.field("twoFactorEnabled", S.bool),
  usePasswordLessLogin: s.field("usePasswordLessLogin", S.bool),
  securityKeys: s.field("securityKeys", S.bool),
  // Relation fields (optional)
  isFollowing: s.field("isFollowing", S.option(S.bool)),
  isFollowed: s.field("isFollowed", S.option(S.bool)),
  hasPendingFollowRequestFromYou: s.field("hasPendingFollowRequestFromYou", S.option(S.bool)),
  hasPendingFollowRequestToYou: s.field("hasPendingFollowRequestToYou", S.option(S.bool)),
  isBlocking: s.field("isBlocking", S.option(S.bool)),
  isBlocked: s.field("isBlocked", S.option(S.bool)),
  isMuted: s.field("isMuted", S.option(S.bool)),
  isRenoteMuted: s.field("isRenoteMuted", S.option(S.bool)),
})

// Drive file schema
let driveFileSchema = S.object(s => {
  id: s.field("id", S.string),
  createdAt: s.field("createdAt", S.string),
  name: s.field("name", S.string),
  type_: s.field("type", S.string),
  md5: s.field("md5", S.string),
  size: s.field("size", S.float),
  isSensitive: s.field("isSensitive", S.bool),
  blurhash: s.field("blurhash", S.option(S.string)),
  url: s.field("url", S.option(S.string)),
  thumbnailUrl: s.field("thumbnailUrl", S.option(S.string)),
  comment: s.field("comment", S.option(S.string)),
  folderId: s.field("folderId", S.option(S.string)),
  userId: s.field("userId", S.option(S.string)),
})

// Drive folder schema
let driveFolderSchema = S.object(s => {
  id: s.field("id", S.string),
  createdAt: s.field("createdAt", S.string),
  name: s.field("name", S.string),
  parentId: s.field("parentId", S.option(S.string)),
})

// Visibility enum
let visibilitySchema = S.union([
  S.literal("public"),
  S.literal("home"),
  S.literal("followers"),
  S.literal("specified"),
])

// Poll choice schema
let pollChoiceSchema = S.object(s => {
  text: s.field("text", S.string),
  votes: s.field("votes", S.int),
  isVoted: s.field("isVoted", S.option(S.bool)),
})

// Poll schema
let pollSchema = S.object(s => {
  multiple: s.field("multiple", S.bool),
  expiresAt: s.field("expiresAt", S.option(S.string)),
  choices: s.field("choices", S.array(pollChoiceSchema)),
})

// Channel schema
let channelSchema = S.object(s => {
  id: s.field("id", S.string),
  name: s.field("name", S.string),
})

// Note schema (recursive)
let noteSchema = S.recursive("Note", _noteSchema => {
  S.object(s => {
    id: s.field("id", S.string),
    createdAt: s.field("createdAt", S.string),
    userId: s.field("userId", S.string),
    user: s.field("user", userLiteSchema),
    text: s.field("text", S.option(S.string)),
    cw: s.field("cw", S.option(S.string)),
    visibility: s.field("visibility", visibilitySchema),
    localOnly: s.field("localOnly", S.option(S.bool)),
    reactionAcceptance: s.field("reactionAcceptance", S.option(S.string)),
    renoteCount: s.field("renoteCount", S.int),
    repliesCount: s.field("repliesCount", S.int),
    reactionEmojis: s.field("reactionEmojis", S.array(emojiSchema)),
    emojis: s.field("emojis", S.array(emojiSchema)),
    fileIds: s.field("fileIds", S.array(S.string)),
    files: s.field("files", S.array(driveFileSchema)),
    replyId: s.field("replyId", S.option(S.string)),
    renoteId: s.field("renoteId", S.option(S.string)),
    uri: s.field("uri", S.option(S.string)),
    url: s.field("url", S.option(S.string)),
    channelId: s.field("channelId", S.option(S.string)),
    channel: s.field("channel", S.option(channelSchema)),
    poll: s.field("poll", S.option(pollSchema)),
  })
})

// Notification type enum
let notificationTypeSchema = S.union([
  S.literal("follow"),
  S.literal("mention"),
  S.literal("reply"),
  S.literal("renote"),
  S.literal("quote"),
  S.literal("reaction"),
  S.literal("pollEnded"),
  S.literal("receiveFollowRequest"),
  S.literal("followRequestAccepted"),
  S.literal("achievementEarned"),
])

// Notification schema
let notificationSchema = S.object(s => {
  id: s.field("id", S.string),
  createdAt: s.field("createdAt", S.string),
  type_: s.field("type", notificationTypeSchema),
  userId: s.field("userId", S.option(S.string)),
  user: s.field("user", S.option(userLiteSchema)),
  note: s.field("note", S.option(noteSchema)),
})

// Timeline response
let timelineResponseSchema = S.array(noteSchema)

// User list response
let userListResponseSchema = S.array(userLiteSchema)

// Notification list response
let notificationListResponseSchema = S.array(notificationSchema)

// Meta response (instance info)
let metaSchema = S.object(s => {
  maintainerName: s.field("maintainerName", S.option(S.string)),
  maintainerEmail: s.field("maintainerEmail", S.option(S.string)),
  version: s.field("version", S.string),
  name: s.field("name", S.option(S.string)),
  shortName: s.field("shortName", S.option(S.string)),
  uri: s.field("uri", S.string),
  description: s.field("description", S.option(S.string)),
  langs: s.field("langs", S.option(S.array(S.string))),
  tosUrl: s.field("tosUrl", S.option(S.string)),
  repositoryUrl: s.field("repositoryUrl", S.string),
  feedbackUrl: s.field("feedbackUrl", S.string),
  disableRegistration: s.field("disableRegistration", S.bool),
  emailRequiredForSignup: s.field("emailRequiredForSignup", S.bool),
  enableHcaptcha: s.field("enableHcaptcha", S.bool),
  enableRecaptcha: s.field("enableRecaptcha", S.bool),
  enableTurnstile: s.field("enableTurnstile", S.bool),
  maxNoteTextLength: s.field("maxNoteTextLength", S.int),
  enableEmail: s.field("enableEmail", S.bool),
  enableServiceWorker: s.field("enableServiceWorker", S.bool),
  emojis: s.field("emojis", S.array(emojiSchema)),
})
