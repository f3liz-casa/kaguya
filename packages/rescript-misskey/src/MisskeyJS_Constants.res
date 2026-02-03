// Constants and enums from misskey-js

// Notification types
@module("misskey-js")
external notificationTypes: array<string> = "notificationTypes"

// Note visibilities
@module("misskey-js")
external noteVisibilities: array<string> = "noteVisibilities"

// Muted note reasons
@module("misskey-js")
external mutedNoteReasons: array<string> = "mutedNoteReasons"

// Following visibility options
@module("misskey-js")
external followingVisibilities: array<string> = "followingVisibilities"

// Followers visibility options
@module("misskey-js")
external followersVisibilities: array<string> = "followersVisibilities"

// Permissions
@module("misskey-js")
external permissions: array<string> = "permissions"

// Moderation log types
@module("misskey-js")
external moderationLogTypes: array<string> = "moderationLogTypes"

// Role policies
@module("misskey-js")
external rolePolicies: array<string> = "rolePolicies"

// Queue types
@module("misskey-js")
external queueTypes: array<string> = "queueTypes"

// Reversi update keys
@module("misskey-js")
external reversiUpdateKeys: array<string> = "reversiUpdateKeys"

// Utility: Convert text to "nya" speak (cat mode)
@module("misskey-js")
external nyaize: string => string = "nyaize"

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
  type t = [#public | #followers | #\"private"]

  let toString = (v: t): string =>
    switch v {
    | #public => "public"
    | #followers => "followers"
    | #\"private" => "private"
    }

  let fromString = (s: string): option<t> =>
    switch s {
    | "public" => Some(#public)
    | "followers" => Some(#followers)
    | "private" => Some(#\"private")
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
