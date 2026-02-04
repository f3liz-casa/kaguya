# API Diff Report: base → cherrypick
## Summary
- **Total Changes**: 294
- **Added Endpoints**: 80
- **Removed Endpoints**: 28
- **Modified Endpoints**: 137
- **Added Schemas**: 8
- **Removed Schemas**: 8
- **Modified Schemas**: 33
- **Breaking Changes**: ⚠️ Yes

### Added Endpoints

- **GET /federation/remote-software (get___federation___remote-software)** [federation]
  federation/remote-software
- **GET /server-info (get___server-info)** [meta]
  server-info
- **POST /admin/avatar-decorations/copy (post___admin___avatar-decorations___copy)** [admin]
  admin/avatar-decorations/copy
- **POST /admin/avatar-decorations/list-remote (post___admin___avatar-decorations___list-remote)** [admin]
  admin/avatar-decorations/list-remote
- **POST /admin/delete-account (post___admin___delete-account)** [admin]
  admin/delete-account
- **POST /admin/delete-all-files-of-a-user (post___admin___delete-all-files-of-a-user)** [admin]
  admin/delete-all-files-of-a-user
- **POST /admin/emoji/steal (post___admin___emoji___steal)** [admin]
  admin/emoji/steal
- **POST /admin/invite/revoke (post___admin___invite___revoke)** [admin]
  admin/invite/revoke
- **POST /admin/queue/jobs (post___admin___queue___jobs)** [admin]
  admin/queue/jobs
- **POST /admin/queue/promote-jobs (post___admin___queue___promote-jobs)** [admin]
  admin/queue/promote-jobs
- **POST /admin/queue/queue-stats (post___admin___queue___queue-stats)** [admin]
  admin/queue/queue-stats
- **POST /admin/queue/queues (post___admin___queue___queues)** [admin]
  admin/queue/queues
- **POST /admin/queue/remove-job (post___admin___queue___remove-job)** [admin]
  admin/queue/remove-job
- **POST /admin/queue/retry-job (post___admin___queue___retry-job)** [admin]
  admin/queue/retry-job
- **POST /admin/queue/show-job (post___admin___queue___show-job)** [admin]
  admin/queue/show-job
- **POST /admin/queue/show-job-logs (post___admin___queue___show-job-logs)** [admin]
  admin/queue/show-job-logs
- **POST /admin/server-info (post___admin___server-info)** [admin]
  admin/server-info
- **POST /chat/history (post___chat___history)** [chat]
  chat/history
- **POST /chat/messages/create-to-room (post___chat___messages___create-to-room)** [chat]
  chat/messages/create-to-room
- **POST /chat/messages/create-to-user (post___chat___messages___create-to-user)** [chat]
  chat/messages/create-to-user
- **POST /chat/messages/delete (post___chat___messages___delete)** [chat]
  chat/messages/delete
- **POST /chat/messages/react (post___chat___messages___react)** [chat]
  chat/messages/react
- **POST /chat/messages/room-timeline (post___chat___messages___room-timeline)** [chat]
  chat/messages/room-timeline
- **POST /chat/messages/search (post___chat___messages___search)** [chat]
  chat/messages/search
- **POST /chat/messages/show (post___chat___messages___show)** [chat]
  chat/messages/show
- **POST /chat/messages/unreact (post___chat___messages___unreact)** [chat]
  chat/messages/unreact
- **POST /chat/messages/user-timeline (post___chat___messages___user-timeline)** [chat]
  chat/messages/user-timeline
- **POST /chat/read-all (post___chat___read-all)** [chat]
  chat/read-all
- **POST /chat/rooms/create (post___chat___rooms___create)** [chat]
  chat/rooms/create
- **POST /chat/rooms/delete (post___chat___rooms___delete)** [chat]
  chat/rooms/delete
- **POST /chat/rooms/invitations/cancel (post___chat___rooms___invitations___cancel)** [chat]
  chat/rooms/invitations/cancel
- **POST /chat/rooms/invitations/create (post___chat___rooms___invitations___create)** [chat]
  chat/rooms/invitations/create
- **POST /chat/rooms/invitations/ignore (post___chat___rooms___invitations___ignore)** [chat]
  chat/rooms/invitations/ignore
- **POST /chat/rooms/invitations/inbox (post___chat___rooms___invitations___inbox)** [chat]
  chat/rooms/invitations/inbox
- **POST /chat/rooms/invitations/outbox (post___chat___rooms___invitations___outbox)** [chat]
  chat/rooms/invitations/outbox
- **POST /chat/rooms/invitations/reject (post___chat___rooms___invitations___reject)** [chat]
  chat/rooms/invitations/reject
- **POST /chat/rooms/join (post___chat___rooms___join)** [chat]
  chat/rooms/join
- **POST /chat/rooms/joining (post___chat___rooms___joining)** [chat]
  chat/rooms/joining
- **POST /chat/rooms/leave (post___chat___rooms___leave)** [chat]
  chat/rooms/leave
- **POST /chat/rooms/members (post___chat___rooms___members)** [chat]
  chat/rooms/members
- **POST /chat/rooms/mute (post___chat___rooms___mute)** [chat]
  chat/rooms/mute
- **POST /chat/rooms/owned (post___chat___rooms___owned)** [chat]
  chat/rooms/owned
- **POST /chat/rooms/show (post___chat___rooms___show)** [chat]
  chat/rooms/show
- **POST /chat/rooms/update (post___chat___rooms___update)** [chat]
  chat/rooms/update
- **POST /drive/files/attached-chat-messages (post___drive___files___attached-chat-messages)** [drive]
  drive/files/attached-chat-messages
- **POST /drive/files/move-bulk (post___drive___files___move-bulk)** [drive]
  drive/files/move-bulk
- **POST /federation/remote-software (post___federation___remote-software)** [federation]
  federation/remote-software
- **POST /flash/gen-token (post___flash___gen-token)** [flash]
  flash/gen-token
- **POST /flash/search (post___flash___search)** [flash]
  flash/search
- **POST /i/auto-delete-settings (post___i___auto-delete-settings)** [account]
  i/auto-delete-settings
- **POST /i/followers-servers (post___i___followers-servers)** [account]
  i/followers-servers
- **POST /i/truncate-account (post___i___truncate-account)**
  i/truncate-account
- **POST /i/update-auto-delete-settings (post___i___update-auto-delete-settings)** [account]
  i/update-auto-delete-settings
- **POST /i/user-group-invites (post___i___user-group-invites)** [account]
  i/user-group-invites
- **POST /notes/bubble-timeline (post___notes___bubble-timeline)** [notes]
  notes/bubble-timeline
- **POST /notes/drafts/count (post___notes___drafts___count)** [notes]
  notes/drafts/count
- **POST /notes/drafts/create (post___notes___drafts___create)** [notes]
  notes/drafts/create
- **POST /notes/drafts/delete (post___notes___drafts___delete)** [notes]
  notes/drafts/delete
- **POST /notes/drafts/list (post___notes___drafts___list)** [notes]
  notes/drafts/list
- **POST /notes/drafts/update (post___notes___drafts___update)** [notes]
  notes/drafts/update
- **POST /notes/events/search (post___notes___events___search)** [notes]
  notes/events/search
- **POST /notes/history (post___notes___history)** [notes]
  notes/history
- **POST /notes/polls/translate (post___notes___polls___translate)** [notes]
  notes/polls/translate
- **POST /notes/show-partial-bulk (post___notes___show-partial-bulk)** [notes]
  notes/show-partial-bulk
- **POST /notes/update (post___notes___update)** [notes]
  notes/update
- **POST /server-info (post___server-info)** [meta]
  server-info
- **POST /users/groups/create (post___users___groups___create)** [groups]
  users/groups/create
- **POST /users/groups/delete (post___users___groups___delete)** [groups]
  users/groups/delete
- **POST /users/groups/invitations/accept (post___users___groups___invitations___accept)** [groups]
  users/groups/invitations/accept
- **POST /users/groups/invitations/reject (post___users___groups___invitations___reject)** [groups]
  users/groups/invitations/reject
- **POST /users/groups/invite (post___users___groups___invite)** [groups]
  users/groups/invite
- **POST /users/groups/joined (post___users___groups___joined)** [groups]
  users/groups/joined
- **POST /users/groups/leave (post___users___groups___leave)** [groups]
  users/groups/leave
- **POST /users/groups/owned (post___users___groups___owned)** [groups]
  users/groups/owned
- **POST /users/groups/pull (post___users___groups___pull)** [groups]
  users/groups/pull
- **POST /users/groups/show (post___users___groups___show)** [groups]
  users/groups/show
- **POST /users/groups/transfer (post___users___groups___transfer)** [groups]
  users/groups/transfer
- **POST /users/groups/update (post___users___groups___update)** [groups]
  users/groups/update
- **POST /users/translate (post___users___translate)** [users]
  users/translate
- **POST /verify-email (post___verify-email)** [account]
  verify-email

### Removed Endpoints

- **GET /meta (get___meta)** [meta]
- **GET /stats (get___stats)** [meta]
- **GET /users/get-skeb-status (get___users___get-skeb-status)** [users]
- **POST /admin/accounts/pending/list (post___admin___accounts___pending___list)** [admin]
- **POST /admin/accounts/pending/revoke (post___admin___accounts___pending___revoke)** [admin]
- **POST /admin/drive/delete-all-files-of-a-user (post___admin___drive___delete-all-files-of-a-user)** [admin]
- **POST /admin/indie-auth/create (post___admin___indie-auth___create)** [admin]
- **POST /admin/indie-auth/delete (post___admin___indie-auth___delete)** [admin]
- **POST /admin/indie-auth/list (post___admin___indie-auth___list)** [admin]
- **POST /admin/indie-auth/update (post___admin___indie-auth___update)** [admin]
- **POST /admin/queue/promote (post___admin___queue___promote)** [admin]
- **POST /admin/regenerate-user-token (post___admin___regenerate-user-token)** [admin]
- **POST /admin/roles/update-inline-policies (post___admin___roles___update-inline-policies)** [admin]
- **POST /admin/show-user-account-move-logs (post___admin___show-user-account-move-logs)** [admin]
- **POST /admin/sso/create (post___admin___sso___create)** [admin]
- **POST /admin/sso/delete (post___admin___sso___delete)** [admin]
- **POST /admin/sso/list (post___admin___sso___list)** [admin]
- **POST /admin/sso/update (post___admin___sso___update)** [admin]
- **POST /admin/unset-user-mutual-link (post___admin___unset-user-mutual-link)** [admin]
- **POST /admin/update-user-name (post___admin___update-user-name)** [admin]
- **POST /announcement (post___announcement)** [meta]
- **POST /channels/featured-games (post___channels___featured-games)** [channels]
- **POST /i/purge-timeline-cache (post___i___purge-timeline-cache)** [account]
- **POST /notes/scheduled/cancel (post___notes___scheduled___cancel)** [notes]
- **POST /notes/scheduled/list (post___notes___scheduled___list)** [notes]
- **POST /users/get-following-birthday-users (post___users___get-following-birthday-users)** [users]
- **POST /users/get-security-info (post___users___get-security-info)** [users]
- **POST /users/get-skeb-status (post___users___get-skeb-status)** [users]

### Modified Endpoints

- **GET /charts/federation** **⚠️ BREAKING**: Changed response
- **GET /emoji** **⚠️ BREAKING**: Changed response
- **GET /notes/reactions**: Changed request body
- **POST /admin/abuse-report/notification-recipient/create** **⚠️ BREAKING**: Changed response
- **POST /admin/abuse-report/notification-recipient/show** **⚠️ BREAKING**: Changed response
- **POST /admin/abuse-report/notification-recipient/update** **⚠️ BREAKING**: Changed response
- **POST /admin/abuse-user-reports**: Changed request body
- **POST /admin/accounts/create** **⚠️ BREAKING**: Changed response
- **POST /admin/accounts/delete**: Changed request body
- **POST /admin/ad/create** **⚠️ BREAKING**: Changed response
- **POST /admin/ad/list**: Changed request body
- **POST /admin/announcements/create** **⚠️ BREAKING**: Changed request body, response
- **POST /admin/announcements/list**: Changed request body
- **POST /admin/announcements/update**: Changed request body
- **POST /admin/avatar-decorations/list**: Changed request body
- **POST /admin/drive/files**: Changed request body
- **POST /admin/drive/show-file** **⚠️ BREAKING**: Changed request body, response
- **POST /admin/emoji/add** **⚠️ BREAKING**: Changed request body, response
- **POST /admin/emoji/list**: Changed request body
- **POST /admin/emoji/list-remote**: Changed request body
- **POST /admin/emoji/update**: Changed request body
- **POST /admin/meta** **⚠️ BREAKING**: Changed response
- **POST /admin/queue/clear**: Changed request body
- **POST /admin/resolve-abuse-user-report**: Changed request body
- **POST /admin/roles/assign**: Changed request body
- **POST /admin/roles/create**: Changed request body
- **POST /admin/roles/update**: Changed request body
- **POST /admin/roles/users**: Changed request body
- **POST /admin/show-moderation-logs**: Changed request body
- **POST /admin/show-user** **⚠️ BREAKING**: Changed response
- **POST /admin/system-webhook/test**: Changed request body
- **POST /admin/update-meta**: Changed request body
- **POST /admin/update-proxy-account** **⚠️ BREAKING**: Changed response
- **POST /announcements**: Changed request body
- **POST /announcements/show** **⚠️ BREAKING**: Changed response
- **POST /antennas/create** **⚠️ BREAKING**: Changed request body, response
- **POST /antennas/show** **⚠️ BREAKING**: Changed response
- **POST /antennas/update** **⚠️ BREAKING**: Changed request body, response
- **POST /blocking/list**: Changed request body
- **POST /channels/followed**: Changed request body
- **POST /channels/owned**: Changed request body
- **POST /channels/search**: Changed request body
- **POST /channels/timeline**: Changed request body
- **POST /charts/federation** **⚠️ BREAKING**: Changed response
- **POST /clips/create** **⚠️ BREAKING**: Changed response
- **POST /clips/list**: Changed request body
- **POST /clips/notes**: Changed request body
- **POST /clips/show** **⚠️ BREAKING**: Changed response
- **POST /clips/update** **⚠️ BREAKING**: Changed response
- **POST /drive/files**: Changed request body
- **POST /drive/files/attached-notes**: Changed request body
- **POST /drive/files/create** **⚠️ BREAKING**: Changed response
- **POST /drive/files/show** **⚠️ BREAKING**: Changed request body, response
- **POST /drive/files/update** **⚠️ BREAKING**: Changed response
- **POST /drive/folders**: Changed request body
- **POST /drive/folders/create** **⚠️ BREAKING**: Changed response
- **POST /drive/folders/show** **⚠️ BREAKING**: Changed response
- **POST /drive/folders/update** **⚠️ BREAKING**: Changed response
- **POST /drive/stream**: Changed request body
- **POST /emoji** **⚠️ BREAKING**: Changed response
- **POST /federation/followers**: Changed request body
- **POST /federation/following**: Changed request body
- **POST /federation/show-instance** **⚠️ BREAKING**: Changed response
- **POST /federation/users**: Changed request body
- **POST /flash/create** **⚠️ BREAKING**: Changed response
- **POST /flash/my**: Changed request body
- **POST /flash/my-likes**: Changed request body
- **POST /flash/show** **⚠️ BREAKING**: Changed response
- **POST /following/create** **⚠️ BREAKING**: Changed response
- **POST /following/delete** **⚠️ BREAKING**: Changed response
- **POST /following/invalidate** **⚠️ BREAKING**: Changed response
- **POST /following/requests/cancel** **⚠️ BREAKING**: Changed response
- **POST /following/requests/list**: Changed request body
- **POST /following/requests/sent**: Changed request body
- **POST /following/update** **⚠️ BREAKING**: Changed response
- **POST /gallery/posts**: Changed request body
- **POST /gallery/posts/create** **⚠️ BREAKING**: Changed response
- **POST /gallery/posts/show** **⚠️ BREAKING**: Changed response
- **POST /gallery/posts/update** **⚠️ BREAKING**: Changed response
- **POST /hashtags/users**: Changed request body
- **POST /i/claim-achievement**: Changed request body
- **POST /i/favorites**: Changed request body
- **POST /i/gallery/likes**: Changed request body
- **POST /i/gallery/posts**: Changed request body
- **POST /i/notifications**: Changed request body
- **POST /i/notifications-grouped**: Changed request body
- **POST /i/page-likes**: Changed request body
- **POST /i/pages**: Changed request body
- **POST /i/revoke-token**: Changed request body
- **POST /i/signin-history**: Changed request body
- **POST /i/update**: Changed request body
- **POST /i/webhooks/show** **⚠️ BREAKING**: Changed response
- **POST /i/webhooks/test**: Changed request body
- **POST /invite/create** **⚠️ BREAKING**: Changed response
- **POST /invite/list**: Changed request body
- **POST /mute/list**: Changed request body
- **POST /notes**: Changed request body
- **POST /notes/children**: Changed request body
- **POST /notes/create** **⚠️ BREAKING**: Changed request body, response
- **POST /notes/global-timeline**: Changed request body
- **POST /notes/hybrid-timeline**: Changed request body
- **POST /notes/local-timeline**: Changed request body
- **POST /notes/mentions**: Changed request body
- **POST /notes/reactions**: Changed request body
- **POST /notes/renotes**: Changed request body
- **POST /notes/replies**: Changed request body
- **POST /notes/search**: Changed request body
- **POST /notes/search-by-tag**: Changed request body
- **POST /notes/show** **⚠️ BREAKING**: Changed response
- **POST /notes/state** **⚠️ BREAKING**: Changed response
- **POST /notes/timeline**: Changed request body
- **POST /notes/user-list-timeline**: Changed request body
- **POST /notifications/create** **⚠️ BREAKING**: Changed response
- **POST /pages/create** **⚠️ BREAKING**: Changed request body, response
- **POST /pages/show** **⚠️ BREAKING**: Changed request body, response
- **POST /pages/update**: Changed request body
- **POST /renote-mute/list**: Changed request body
- **POST /reversi/games**: Changed request body
- **POST /reversi/match** **⚠️ BREAKING**: Changed response
- **POST /reversi/show-game** **⚠️ BREAKING**: Changed response
- **POST /reversi/verify** **⚠️ BREAKING**: Changed response
- **POST /roles/notes**: Changed request body
- **POST /roles/users**: Changed request body
- **POST /users**: Changed request body
- **POST /users/clips**: Changed request body
- **POST /users/flashs**: Changed request body
- **POST /users/followers**: Changed request body
- **POST /users/following**: Changed request body
- **POST /users/gallery/posts**: Changed request body
- **POST /users/lists/get-memberships**: Changed request body
- **POST /users/lists/show** **⚠️ BREAKING**: Changed response
- **POST /users/notes**: Changed request body
- **POST /users/pages**: Changed request body
- **POST /users/report-abuse**: Changed request body
- **POST /users/search-by-username-and-host**: Changed request body
- **POST /users/show**: Changed request body
- **POST /v2/admin/emoji/list**: Changed request body

### Added Schemas

- `Achievement`
- `AchievementName`
- `NoteHistory`
- `NoteReactionWithNote`
- `QueueJob`
- `QueueMetrics`
- `UserGroup`
- `UserWebhook`

### Removed Schemas

- `AbuseUserReport`
- `FlashLike`
- `FollowRequest`
- `GalleryLike`
- `ModerationLog`
- `PageLike`
- `UserAccountMoveLog`
- `UserListMembership`

### Modified Schemas

- `AbuseReportNotificationRecipient` **⚠️ BREAKING**
- `Ad` **⚠️ BREAKING**
- `Announcement` **⚠️ BREAKING**
- `Antenna` **⚠️ BREAKING**
- `ChatMessage` **⚠️ BREAKING**
- `ChatMessageLite` **⚠️ BREAKING**
- `ChatMessageLiteFor1on1` **⚠️ BREAKING**
- `ChatMessageLiteForRoom` **⚠️ BREAKING**
- `ChatRoom` **⚠️ BREAKING**
- `ChatRoomInvitation` **⚠️ BREAKING**
- `ChatRoomMembership` **⚠️ BREAKING**
- `Clip` **⚠️ BREAKING**
- `DriveFile` **⚠️ BREAKING**
- `DriveFolder` **⚠️ BREAKING**
- `EmojiDetailed` **⚠️ BREAKING**
- `EmojiSimple` **⚠️ BREAKING**
- `FederationInstance` **⚠️ BREAKING**
- `Flash` **⚠️ BREAKING**
- `GalleryPost` **⚠️ BREAKING**
- `InviteCode` **⚠️ BREAKING**
- `MeDetailedOnly` **⚠️ BREAKING**
- `MetaDetailedOnly` **⚠️ BREAKING**
- `MetaLite` **⚠️ BREAKING**
- `Note` **⚠️ BREAKING**
- `NoteDraft` **⚠️ BREAKING**
- `NoteFavorite` **⚠️ BREAKING**
- `NoteReaction` **⚠️ BREAKING**
- `Page` **⚠️ BREAKING**
- `ReversiGameDetailed` **⚠️ BREAKING**
- `ReversiGameLite` **⚠️ BREAKING**
- `RolePolicies` **⚠️ BREAKING**
- `UserDetailedNotMeOnly` **⚠️ BREAKING**
- `UserLite` **⚠️ BREAKING**
---
*Generated on 2026-02-03T14:17:06.652Z*