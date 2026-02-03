// Low-level bindings to misskey-js api.APIClient
// This module provides direct FFI bindings with minimal abstraction

open MisskeyJS_Common

// Custom fetch-like interface type
type fetchLike

// APIClient configuration
type clientConfig = {
  origin: string,
  credential?: string,
  fetch?: fetchLike,
}

// APIClient class binding
type t

@module("misskey-js") @scope("api") @new
external make: clientConfig => t = "APIClient"

@get external origin: t => string = "origin"
@get external credential: t => option<string> = "credential"

// Generic request method - returns Promise
// Note: In practice, you'll want to create typed wrappers for specific endpoints
@send
external request: (
  t,
  ~endpoint: string,
  ~params: JSON.t=?,
  ~credential: string=?,
) => promise<JSON.t> = "request"

// Typed request for specific endpoints
// We'll add more endpoint-specific bindings as needed

// meta endpoint
type metaParams = {detail?: bool}
@send
external requestMeta: (t, @as("meta") _, ~params: metaParams=?) => promise<JSON.t> = "request"

// i endpoint (get current user)
@send
external requestI: (t, @as("i") _) => promise<JSON.t> = "request"

// i/update endpoint
type iUpdateParams = {
  name?: string,
  description?: string,
  lang?: string,
  location?: string,
  birthday?: string,
  avatarId?: id,
  bannerId?: id,
  fields?: array<JSON.t>,
  isLocked?: bool,
  isExplorable?: bool,
  hideOnlineStatus?: bool,
  publicReactions?: bool,
  carefulBot?: bool,
  autoAcceptFollowed?: bool,
  noCrawle?: bool,
  preventAiLearning?: bool,
  isBot?: bool,
  isCat?: bool,
  injectFeaturedNote?: bool,
  receiveAnnouncementEmail?: bool,
  alwaysMarkNsfw?: bool,
  autoSensitive?: bool,
  ffVisibility?: string,
  mutedWords?: array<array<string>>,
  mutedInstances?: array<string>,
  notificationRecieveConfig?: JSON.t,
  emailNotificationTypes?: array<string>,
}

@send
external requestIUpdate: (t, @as("i/update") _, ~params: iUpdateParams) => promise<JSON.t> =
  "request"

// notes/create endpoint
type pollParams = {
  choices: array<string>,
  multiple?: bool,
  expiresAt?: int,
  expiredAfter?: int,
}

type noteCreateParams = {
  visibility?: string,
  visibleUserIds?: array<id>,
  cw?: string,
  localOnly?: bool,
  reactionAcceptance?: string,
  text?: string,
  fileIds?: array<id>,
  poll?: pollParams,
  replyId?: id,
  renoteId?: id,
  channelId?: id,
}

@send
external requestNotesCreate: (
  t,
  @as("notes/create") _,
  ~params: noteCreateParams,
) => promise<JSON.t> = "request"

// notes/show endpoint
type notesShowParams = {noteId: id}
@send
external requestNotesShow: (t, @as("notes/show") _, ~params: notesShowParams) => promise<JSON.t> =
  "request"

// notes/delete endpoint
type notesDeleteParams = {noteId: id}
@send
external requestNotesDelete: (
  t,
  @as("notes/delete") _,
  ~params: notesDeleteParams,
) => promise<JSON.t> = "request"

// notes/reactions/create endpoint
type notesReactionsCreateParams = {
  noteId: id,
  reaction: string,
}
@send
external requestNotesReactionsCreate: (
  t,
  @as("notes/reactions/create") _,
  ~params: notesReactionsCreateParams,
) => promise<JSON.t> = "request"

// notes/reactions/delete endpoint
type notesReactionsDeleteParams = {noteId: id}
@send
external requestNotesReactionsDelete: (
  t,
  @as("notes/reactions/delete") _,
  ~params: notesReactionsDeleteParams,
) => promise<JSON.t> = "request"

// notes/timeline endpoint
type notesTimelineParams = {
  limit?: int,
  sinceId?: id,
  untilId?: id,
  sinceDate?: int,
  untilDate?: int,
  includeMyRenotes?: bool,
  includeRenotedMyNotes?: bool,
  includeLocalRenotes?: bool,
  withFiles?: bool,
  withRenotes?: bool,
}

@send
external requestNotesTimeline: (
  t,
  @as("notes/timeline") _,
  ~params: notesTimelineParams=?,
) => promise<array<JSON.t>> = "request"

// notes/local-timeline endpoint
type notesLocalTimelineParams = {
  limit?: int,
  sinceId?: id,
  untilId?: id,
  sinceDate?: int,
  untilDate?: int,
  withFiles?: bool,
  withRenotes?: bool,
  withReplies?: bool,
  excludeNsfw?: bool,
}

@send
external requestNotesLocalTimeline: (
  t,
  @as("notes/local-timeline") _,
  ~params: notesLocalTimelineParams=?,
) => promise<array<JSON.t>> = "request"

// notes/global-timeline endpoint
type notesGlobalTimelineParams = {
  limit?: int,
  sinceId?: id,
  untilId?: id,
  sinceDate?: int,
  untilDate?: int,
  withFiles?: bool,
  withRenotes?: bool,
}

@send
external requestNotesGlobalTimeline: (
  t,
  @as("notes/global-timeline") _,
  ~params: notesGlobalTimelineParams=?,
) => promise<array<JSON.t>> = "request"

// users/show endpoint
type usersShowParams =
  | @as("userId") UserId({userId: id})
  | @as("username") Username({username: string, host?: string})

@send
external requestUsersShow: (t, @as("users/show") _, ~params: JSON.t) => promise<JSON.t> = "request"

// users/notes endpoint
type usersNotesParams = {
  userId: id,
  limit?: int,
  sinceId?: id,
  untilId?: id,
  sinceDate?: int,
  untilDate?: int,
  includeReplies?: bool,
  includeMyRenotes?: bool,
  withFiles?: bool,
  withRenotes?: bool,
}

@send
external requestUsersNotes: (
  t,
  @as("users/notes") _,
  ~params: usersNotesParams,
) => promise<array<JSON.t>> = "request"

// following/create endpoint
type followingCreateParams = {userId: id}
@send
external requestFollowingCreate: (
  t,
  @as("following/create") _,
  ~params: followingCreateParams,
) => promise<JSON.t> = "request"

// following/delete endpoint
type followingDeleteParams = {userId: id}
@send
external requestFollowingDelete: (
  t,
  @as("following/delete") _,
  ~params: followingDeleteParams,
) => promise<JSON.t> = "request"

// i/notifications endpoint
type iNotificationsParams = {
  limit?: int,
  sinceId?: id,
  untilId?: id,
  following?: bool,
  markAsRead?: bool,
  includeTypes?: array<string>,
  excludeTypes?: array<string>,
}

@send
external requestINotifications: (
  t,
  @as("i/notifications") _,
  ~params: iNotificationsParams=?,
) => promise<array<JSON.t>> = "request"

// notifications/mark-all-as-read endpoint
@send
external requestNotificationsMarkAllAsRead: (
  t,
  @as("notifications/mark-all-as-read") _,
) => promise<JSON.t> = "request"

// drive/files endpoint
type driveFilesParams = {
  limit?: int,
  sinceId?: id,
  untilId?: id,
  folderId?: id,
  @as("type") type_?: string,
}

@send
external requestDriveFiles: (
  t,
  @as("drive/files") _,
  ~params: driveFilesParams=?,
) => promise<array<JSON.t>> = "request"

// drive/files/create endpoint (multipart/form-data)
type driveFilesCreateParams = {
  file: Blob.t,
  folderId?: id,
  name?: string,
  comment?: string,
  isSensitive?: bool,
  force?: bool,
}

@send
external requestDriveFilesCreate: (
  t,
  @as("drive/files/create") _,
  ~params: driveFilesCreateParams,
) => promise<JSON.t> = "request"

// drive/files/delete endpoint
type driveFilesDeleteParams = {fileId: id}
@send
external requestDriveFilesDelete: (
  t,
  @as("drive/files/delete") _,
  ~params: driveFilesDeleteParams,
) => promise<JSON.t> = "request"

// drive/folders/create endpoint
type driveFoldersCreateParams = {
  name: string,
  parentId?: id,
}

@send
external requestDriveFoldersCreate: (
  t,
  @as("drive/folders/create") _,
  ~params: driveFoldersCreateParams,
) => promise<JSON.t> = "request"

// antennas/list endpoint
@send
external requestAntennasList: (t, @as("antennas/list") _) => promise<array<JSON.t>> = "request"

// antennas/notes endpoint
type antennasNotesParams = {
  antennaId: id,
  limit?: int,
  sinceId?: id,
  untilId?: id,
  sinceDate?: int,
  untilDate?: int,
}

@send
external requestAntennasNotes: (
  t,
  @as("antennas/notes") _,
  ~params: antennasNotesParams,
) => promise<array<JSON.t>> = "request"

// users/lists/list endpoint
type usersListsListParams = {userId?: id}

@send
external requestUsersListsList: (
  t,
  @as("users/lists/list") _,
  ~params: usersListsListParams=?,
) => promise<array<JSON.t>> = "request"

// notes/user-list-timeline endpoint
type notesUserListTimelineParams = {
  listId: id,
  limit?: int,
  sinceId?: id,
  untilId?: id,
  sinceDate?: int,
  untilDate?: int,
  allowPartial?: bool,
  includeMyRenotes?: bool,
  includeRenotedMyNotes?: bool,
  includeLocalRenotes?: bool,
  withRenotes?: bool,
  withFiles?: bool,
}

@send
external requestNotesUserListTimeline: (
  t,
  @as("notes/user-list-timeline") _,
  ~params: notesUserListTimelineParams,
) => promise<array<JSON.t>> = "request"

// channels/followed endpoint
type channelsFollowedParams = {
  sinceId?: id,
  untilId?: id,
  sinceDate?: int,
  untilDate?: int,
  limit?: int,
}

@send
external requestChannelsFollowed: (
  t,
  @as("channels/followed") _,
  ~params: channelsFollowedParams=?,
) => promise<array<JSON.t>> = "request"

// channels/timeline endpoint
type channelsTimelineParams = {
  channelId: id,
  limit?: int,
  sinceId?: id,
  untilId?: id,
  sinceDate?: int,
  untilDate?: int,
  allowPartial?: bool,
}

@send
external requestChannelsTimeline: (
  t,
  @as("channels/timeline") _,
  ~params: channelsTimelineParams,
) => promise<array<JSON.t>> = "request"
