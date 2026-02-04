// Constants and enums - Pure ReScript implementation
// These constants match the Misskey API specification

// Notification types
let notificationTypes = [
  "note",
  "follow",
  "mention",
  "reply",
  "renote",
  "quote",
  "reaction",
  "pollEnded",
  "scheduledNotePosted",
  "scheduledNotePostFailed",
  "receiveFollowRequest",
  "followRequestAccepted",
  "app",
  "roleAssigned",
  "chatRoomInvitationReceived",
  "achievementEarned",
  "exportCompleted",
  "test",
  "login",
  "createToken",
]

// Note visibilities
let noteVisibilities = ["public", "home", "followers", "specified"]

// Muted note reasons
let mutedNoteReasons = ["word", "manual", "spam", "other"]

// Following visibility options
let followingVisibilities = ["public", "followers", "private"]

// Followers visibility options
let followersVisibilities = ["public", "followers", "private"]

// Permissions
let permissions = [
  "read:account",
  "write:account",
  "read:blocks",
  "write:blocks",
  "read:drive",
  "write:drive",
  "read:favorites",
  "write:favorites",
  "read:following",
  "write:following",
  "read:messaging",
  "write:messaging",
  "read:mutes",
  "write:mutes",
  "write:notes",
  "read:notifications",
  "write:notifications",
  "read:reactions",
  "write:reactions",
  "write:votes",
  "read:pages",
  "write:pages",
  "write:page-likes",
  "read:page-likes",
  "read:user-groups",
  "write:user-groups",
  "read:channels",
  "write:channels",
  "read:gallery",
  "write:gallery",
  "read:gallery-likes",
  "write:gallery-likes",
  "read:flash",
  "write:flash",
  "read:flash-likes",
  "write:flash-likes",
  "read:admin:abuse-user-reports",
  "write:admin:delete-account",
  "write:admin:delete-all-files-of-a-user",
  "read:admin:index-stats",
  "read:admin:table-stats",
  "read:admin:user-ips",
  "read:admin:meta",
  "write:admin:reset-password",
  "write:admin:resolve-abuse-user-report",
  "write:admin:send-email",
  "read:admin:server-info",
  "read:admin:show-moderation-log",
  "read:admin:show-user",
  "write:admin:suspend-user",
  "write:admin:unset-user-avatar",
  "write:admin:unset-user-banner",
  "write:admin:unsuspend-user",
  "write:admin:meta",
  "write:admin:user-note",
  "write:admin:roles",
  "read:admin:roles",
  "write:admin:relays",
  "read:admin:relays",
  "write:admin:invite-codes",
  "read:admin:invite-codes",
  "write:admin:announcements",
  "read:admin:announcements",
  "write:admin:avatar-decorations",
  "read:admin:avatar-decorations",
  "write:admin:federation",
  "write:admin:account",
  "read:admin:account",
  "write:admin:emoji",
  "read:admin:emoji",
  "write:admin:queue",
  "read:admin:queue",
  "write:admin:promo",
  "write:admin:drive",
  "read:admin:drive",
  "write:admin:ad",
  "read:admin:ad",
  "write:invite-codes",
  "read:invite-codes",
  "write:clip-favorite",
  "read:clip-favorite",
  "read:federation",
  "write:report-abuse",
  "write:chat",
  "read:chat",
]

// Moderation log types
let moderationLogTypes = [
  "updateServerSettings",
  "suspend",
  "unsuspend",
  "updateUserNote",
  "addCustomEmoji",
  "updateCustomEmoji",
  "deleteCustomEmoji",
  "assignRole",
  "unassignRole",
  "createRole",
  "updateRole",
  "deleteRole",
  "clearQueue",
  "promoteQueue",
  "deleteDriveFile",
  "deleteNote",
  "createGlobalAnnouncement",
  "createUserAnnouncement",
  "updateGlobalAnnouncement",
  "updateUserAnnouncement",
  "deleteGlobalAnnouncement",
  "deleteUserAnnouncement",
  "resetPassword",
  "suspendRemoteInstance",
  "unsuspendRemoteInstance",
  "updateRemoteInstanceNote",
  "markSensitiveDriveFile",
  "unmarkSensitiveDriveFile",
  "resolveAbuseReport",
  "forwardAbuseReport",
  "updateAbuseReportNote",
  "createInvitation",
  "createAd",
  "updateAd",
  "deleteAd",
  "createAvatarDecoration",
  "updateAvatarDecoration",
  "deleteAvatarDecoration",
  "unsetUserAvatar",
  "unsetUserBanner",
  "createSystemWebhook",
  "updateSystemWebhook",
  "deleteSystemWebhook",
  "createAbuseReportNotificationRecipient",
  "updateAbuseReportNotificationRecipient",
  "deleteAbuseReportNotificationRecipient",
  "deleteAccount",
  "deletePage",
  "deleteFlash",
  "deleteGalleryPost",
  "deleteChatRoom",
  "updateProxyAccountDescription",
]

// Role policies
let rolePolicies = [
  "gtlAvailable",
  "ltlAvailable",
  "canPublicNote",
  "mentionLimit",
  "canInvite",
  "inviteLimit",
  "inviteLimitCycle",
  "inviteExpirationTime",
  "canManageCustomEmojis",
  "canManageAvatarDecorations",
  "canSearchNotes",
  "canSearchUsers",
  "canUseTranslator",
  "canHideAds",
  "driveCapacityMb",
  "maxFileSizeMb",
  "alwaysMarkNsfw",
  "canUpdateBioMedia",
  "pinLimit",
  "antennaLimit",
  "wordMuteLimit",
  "webhookLimit",
  "clipLimit",
  "noteEachClipsLimit",
  "userListLimit",
  "userEachUserListsLimit",
  "rateLimitFactor",
  "avatarDecorationLimit",
  "canImportAntennas",
  "canImportBlocking",
  "canImportFollowing",
  "canImportMuting",
  "canImportUserLists",
  "chatAvailability",
  "uploadableFileTypes",
  "noteDraftLimit",
  "scheduledNoteLimit",
  "watermarkAvailable",
]

// Queue types
let queueTypes = [
  "system",
  "endedPollNotification",
  "postScheduledNote",
  "deliver",
  "inbox",
  "db",
  "relationship",
  "objectStorage",
  "userWebhookDeliver",
  "systemWebhookDeliver",
]

// Reversi update keys
let reversiUpdateKeys = [
  "map",
  "bw",
  "isLlotheo",
  "canPutEverywhere",
  "loopedBoard",
  "timeLimitForEachTurn",
]

module NotificationType = {
  type t = [
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

  let toString = (t: t): string =>
    switch t {
    | #note => "note"
    | #follow => "follow"
    | #mention => "mention"
    | #reply => "reply"
    | #renote => "renote"
    | #quote => "quote"
    | #reaction => "reaction"
    | #pollEnded => "pollEnded"
    | #scheduledNotePosted => "scheduledNotePosted"
    | #scheduledNotePostFailed => "scheduledNotePostFailed"
    | #receiveFollowRequest => "receiveFollowRequest"
    | #followRequestAccepted => "followRequestAccepted"
    | #app => "app"
    | #roleAssigned => "roleAssigned"
    | #chatRoomInvitationReceived => "chatRoomInvitationReceived"
    | #achievementEarned => "achievementEarned"
    | #exportCompleted => "exportCompleted"
    | #test => "test"
    | #login => "login"
    | #createToken => "createToken"
    }

  let fromString = (s: string): option<t> =>
    switch s {
    | "note" => Some(#note)
    | "follow" => Some(#follow)
    | "mention" => Some(#mention)
    | "reply" => Some(#reply)
    | "renote" => Some(#renote)
    | "quote" => Some(#quote)
    | "reaction" => Some(#reaction)
    | "pollEnded" => Some(#pollEnded)
    | "scheduledNotePosted" => Some(#scheduledNotePosted)
    | "scheduledNotePostFailed" => Some(#scheduledNotePostFailed)
    | "receiveFollowRequest" => Some(#receiveFollowRequest)
    | "followRequestAccepted" => Some(#followRequestAccepted)
    | "app" => Some(#app)
    | "roleAssigned" => Some(#roleAssigned)
    | "chatRoomInvitationReceived" => Some(#chatRoomInvitationReceived)
    | "achievementEarned" => Some(#achievementEarned)
    | "exportCompleted" => Some(#exportCompleted)
    | "test" => Some(#test)
    | "login" => Some(#login)
    | "createToken" => Some(#createToken)
    | _ => None
    }
}

module Visibility = {
  type t = [#public | #home | #followers | #specified]

  let toString = (v: t): string =>
    switch v {
    | #public => "public"
    | #home => "home"
    | #followers => "followers"
    | #specified => "specified"
    }

  let fromString = (s: string): option<t> =>
    switch s {
    | "public" => Some(#public)
    | "home" => Some(#home)
    | "followers" => Some(#followers)
    | "specified" => Some(#specified)
    | _ => None
    }
}

module FollowVisibility = {
  type t = [#public | #followers | #"private"]

  let toString = (v: t): string =>
    switch v {
    | #public => "public"
    | #followers => "followers"
    | #"private" => "private"
    }

  let fromString = (s: string): option<t> =>
    switch s {
    | "public" => Some(#public)
    | "followers" => Some(#followers)
    | "private" => Some(#"private")
    | _ => None
    }
}

module MutedNoteReason = {
  type t = [#word | #manual | #spam | #other]

  let toString = (r: t): string =>
    switch r {
    | #word => "word"
    | #manual => "manual"
    | #spam => "spam"
    | #other => "other"
    }

  let fromString = (s: string): option<t> =>
    switch s {
    | "word" => Some(#word)
    | "manual" => Some(#manual)
    | "spam" => Some(#spam)
    | "other" => Some(#other)
    | _ => None
    }
}
