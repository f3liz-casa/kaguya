// Notification entity types

open MisskeyJS_Common

// Base notification structure
type baseNotification = {
  id: id,
  createdAt: dateString,
  isRead: bool,
}

// Different notification types (discriminated union)
type notificationBody =
  | @as("note") Note({note: JSON.t}) // MisskeyJS_Note.note
  | @as("follow") Follow({user: JSON.t}) // MisskeyJS_User.userLite
  | @as("mention") Mention({user: JSON.t, note: JSON.t})
  | @as("reply") Reply({user: JSON.t, note: JSON.t})
  | @as("renote") Renote({user: JSON.t, note: JSON.t})
  | @as("quote") Quote({user: JSON.t, note: JSON.t})
  | @as("reaction") Reaction({
      user: JSON.t,
      note: JSON.t,
      reaction: string,
    })
  | @as("pollEnded") PollEnded({note: JSON.t})
  | @as("scheduledNotePosted") ScheduledNotePosted({note: JSON.t})
  | @as("scheduledNotePostFailed") ScheduledNotePostFailed({note: JSON.t})
  | @as("receiveFollowRequest") ReceiveFollowRequest({user: JSON.t})
  | @as("followRequestAccepted") FollowRequestAccepted({user: JSON.t})
  | @as("roleAssigned") RoleAssigned({roleId: id})
  | @as("achievementEarned") AchievementEarned({achievement: string})
  | @as("exportCompleted") ExportCompleted({exportedEntity: string, fileId: id})
  | @as("login") Login({})
  | @as("app") App({
      header: option<string>,
      body: string,
      icon: option<string>,
    })
  | @as("test") Test({})

type notification = {
  ...baseNotification,
  @as("type") type_: notificationBody,
}

type t = notification
