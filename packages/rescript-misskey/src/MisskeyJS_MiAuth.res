// High-level MiAuth API for OAuth-like authentication flow
// See: https://misskey-hub.net/ja/docs/for-developers/api/token/miauth/

open MisskeyJS_Common

// ============================================================
// Types
// ============================================================

type permission = [
  | #read_account
  | #write_account
  | #read_blocks
  | #write_blocks
  | #read_drive
  | #write_drive
  | #read_favorites
  | #write_favorites
  | #read_following
  | #write_following
  | #read_messaging
  | #write_messaging
  | #read_mutes
  | #write_mutes
  | #write_notes
  | #read_notifications
  | #write_notifications
  | #read_reactions
  | #write_reactions
  | #write_votes
  | #read_pages
  | #write_pages
  | #write_page_likes
  | #read_page_likes
  | #read_user_groups
  | #write_user_groups
  | #read_channels
  | #write_channels
  | #read_gallery
  | #write_gallery
  | #read_gallery_likes
  | #write_gallery_likes
  | #read_flash
  | #write_flash
  | #read_flash_likes
  | #write_flash_likes
  | #read_admin_abuse_user_reports
  | #write_admin_delete_account
  | #write_admin_delete_all_files_of_a_user
  | #read_admin_index_stats
  | #read_admin_table_stats
  | #read_admin_user_ips
  | #read_admin_meta
  | #write_admin_reset_password
  | #write_admin_resolve_abuse_user_report
  | #write_admin_send_email
  | #read_admin_server_info
  | #read_admin_show_moderation_log
  | #read_admin_show_user
  | #read_admin_show_users
  | #write_admin_suspend_user
  | #write_admin_unset_user_avatar
  | #write_admin_unset_user_banner
  | #write_admin_unsuspend_user
  | #write_admin_meta
  | #write_admin_user_note
  | #write_admin_roles
  | #read_admin_roles
  | #write_admin_relays
  | #read_admin_relays
  | #write_admin_invite_codes
  | #read_admin_invite_codes
  | #write_admin_announcements
  | #read_admin_announcements
  | #write_admin_avatar_decorations
  | #read_admin_avatar_decorations
  | #write_admin_federation
  | #write_admin_account
  | #read_admin_account
  | #write_admin_emoji
  | #read_admin_emoji
  | #write_admin_queue
  | #read_admin_queue
  | #write_admin_promo
  | #write_admin_drive
  | #read_admin_drive
  | #read_admin_stream
  | #write_admin_ad
  | #read_admin_ad
  | #write_invite_codes
  | #read_invite_codes
  | #write_clip
  | #read_clip
  | #write_clip_favorite
  | #read_clip_favorite
  | #read_federation
  | #write_report_abuse
]

let permissionToString = (perm: permission): string => {
  switch perm {
  | #read_account => "read:account"
  | #write_account => "write:account"
  | #read_blocks => "read:blocks"
  | #write_blocks => "write:blocks"
  | #read_drive => "read:drive"
  | #write_drive => "write:drive"
  | #read_favorites => "read:favorites"
  | #write_favorites => "write:favorites"
  | #read_following => "read:following"
  | #write_following => "write:following"
  | #read_messaging => "read:messaging"
  | #write_messaging => "write:messaging"
  | #read_mutes => "read:mutes"
  | #write_mutes => "write:mutes"
  | #write_notes => "write:notes"
  | #read_notifications => "read:notifications"
  | #write_notifications => "write:notifications"
  | #read_reactions => "read:reactions"
  | #write_reactions => "write:reactions"
  | #write_votes => "write:votes"
  | #read_pages => "read:pages"
  | #write_pages => "write:pages"
  | #write_page_likes => "write:page-likes"
  | #read_page_likes => "read:page-likes"
  | #read_user_groups => "read:user-groups"
  | #write_user_groups => "write:user-groups"
  | #read_channels => "read:channels"
  | #write_channels => "write:channels"
  | #read_gallery => "read:gallery"
  | #write_gallery => "write:gallery"
  | #read_gallery_likes => "read:gallery-likes"
  | #write_gallery_likes => "write:gallery-likes"
  | #read_flash => "read:flash"
  | #write_flash => "write:flash"
  | #read_flash_likes => "read:flash-likes"
  | #write_flash_likes => "write:flash-likes"
  | #read_admin_abuse_user_reports => "read:admin:abuse-user-reports"
  | #write_admin_delete_account => "write:admin:delete-account"
  | #write_admin_delete_all_files_of_a_user => "write:admin:delete-all-files-of-a-user"
  | #read_admin_index_stats => "read:admin:index-stats"
  | #read_admin_table_stats => "read:admin:table-stats"
  | #read_admin_user_ips => "read:admin:user-ips"
  | #read_admin_meta => "read:admin:meta"
  | #write_admin_reset_password => "write:admin:reset-password"
  | #write_admin_resolve_abuse_user_report => "write:admin:resolve-abuse-user-report"
  | #write_admin_send_email => "write:admin:send-email"
  | #read_admin_server_info => "read:admin:server-info"
  | #read_admin_show_moderation_log => "read:admin:show-moderation-log"
  | #read_admin_show_user => "read:admin:show-user"
  | #read_admin_show_users => "read:admin:show-users"
  | #write_admin_suspend_user => "write:admin:suspend-user"
  | #write_admin_unset_user_avatar => "write:admin:unset-user-avatar"
  | #write_admin_unset_user_banner => "write:admin:unset-user-banner"
  | #write_admin_unsuspend_user => "write:admin:unsuspend-user"
  | #write_admin_meta => "write:admin:meta"
  | #write_admin_user_note => "write:admin:user-note"
  | #write_admin_roles => "write:admin:roles"
  | #read_admin_roles => "read:admin:roles"
  | #write_admin_relays => "write:admin:relays"
  | #read_admin_relays => "read:admin:relays"
  | #write_admin_invite_codes => "write:admin:invite-codes"
  | #read_admin_invite_codes => "read:admin:invite-codes"
  | #write_admin_announcements => "write:admin:announcements"
  | #read_admin_announcements => "read:admin:announcements"
  | #write_admin_avatar_decorations => "write:admin:avatar-decorations"
  | #read_admin_avatar_decorations => "read:admin:avatar-decorations"
  | #write_admin_federation => "write:admin:federation"
  | #write_admin_account => "write:admin:account"
  | #read_admin_account => "read:admin:account"
  | #write_admin_emoji => "write:admin:emoji"
  | #read_admin_emoji => "read:admin:emoji"
  | #write_admin_queue => "write:admin:queue"
  | #read_admin_queue => "read:admin:queue"
  | #write_admin_promo => "write:admin:promo"
  | #write_admin_drive => "write:admin:drive"
  | #read_admin_drive => "read:admin:drive"
  | #read_admin_stream => "read:admin:stream"
  | #write_admin_ad => "write:admin:ad"
  | #read_admin_ad => "read:admin:ad"
  | #write_invite_codes => "write:invite-codes"
  | #read_invite_codes => "read:invite-codes"
  | #write_clip => "write:clip"
  | #read_clip => "read:clip"
  | #write_clip_favorite => "write:clip-favorite"
  | #read_clip_favorite => "read:clip-favorite"
  | #read_federation => "read:federation"
  | #write_report_abuse => "write:report-abuse"
  }
}

type authSession = {
  sessionId: string,
  authUrl: string,
}

type checkResult = {
  token: option<string>,
  user: option<JSON.t>,
}

// Internal: Error handler
let handleError = (error: exn): result<'a, [> #APIError(apiError) | #UnknownError(exn)]> => {
  switch isAPIError(error) {
  | Some(apiErr) => Error(#APIError(apiErr))
  | None => Error(#UnknownError(error))
  }
}

// ============================================================
// Global bindings
// ============================================================

@val
external encodeURIComponent: string => string = "encodeURIComponent"

// Fetch API bindings
module Fetch = {
  type response
  type requestInit = {method: [#GET | #POST]}

  @val
  external fetch: (string, requestInit) => promise<response> = "fetch"

  module Response = {
    @get external ok: response => bool = "ok"
    @get external status: response => int = "status"
    @send external json: response => promise<JSON.t> = "json"
  }
}

// ============================================================
// Crypto bindings for generating random session IDs
// ============================================================

@val @scope("crypto")
external getRandomValues: Js.TypedArray2.Uint8Array.t => Js.TypedArray2.Uint8Array.t =
  "getRandomValues"

@new external makeUint8Array: int => Js.TypedArray2.Uint8Array.t = "Uint8Array"

// Generate a random session ID
let generateSessionId = (): string => {
  let array = makeUint8Array(16)
  let _ = getRandomValues(array)

  // Convert to hex string
  let hex = ref("")
  for i in 0 to 15 {
    let byte = Js.TypedArray2.Uint8Array.unsafe_get(array, i)
    let hexByte = byte->Int.toString(~radix=16)
    let padded = String.length(hexByte) == 1 ? "0" ++ hexByte : hexByte
    hex := hex.contents ++ padded
  }

  hex.contents
}

// ============================================================
// MiAuth Flow
// ============================================================

// Step 1: Generate auth URL
// Returns a session ID and auth URL that the user should be redirected to
let generateAuthUrl = (
  ~origin: string,
  ~name: string,
  ~permissions: array<permission>,
  ~callback: option<string>=?,
  ~icon: option<string>=?,
  (),
): authSession => {
  let sessionId = generateSessionId()
  let permissionStrings = permissions->Array.map(permissionToString)

  // Build auth URL manually according to MiAuth spec
  // Format: {origin}/miauth/{session}?name={name}&permission={perm1,perm2,...}
  let permissionParam = permissionStrings->Array.join(",")
  let encodedName = encodeURIComponent(name)
  let encodedPermission = encodeURIComponent(permissionParam)

  let baseUrl = `${origin}/miauth/${sessionId}?name=${encodedName}&permission=${encodedPermission}`

  let withCallback = switch callback {
  | Some(cb) => {
      let encodedCallback = encodeURIComponent(cb)
      `${baseUrl}&callback=${encodedCallback}`
    }
  | None => baseUrl
  }

  let authUrl = switch icon {
  | Some(ic) => {
      let encodedIcon = encodeURIComponent(ic)
      `${withCallback}&icon=${encodedIcon}`
    }
  | None => withCallback
  }

  {sessionId, authUrl}
}

// Step 2: Check if user has authorized
// POST to /api/miauth/{session}/check to get the token
let check = async (~origin: string, ~sessionId: string): result<
  checkResult,
  [> #APIError(apiError) | #UnknownError(exn)],
> => {
  // According to the MiAuth spec, we need to POST to /api/miauth/{session}/check
  // This is NOT a regular API endpoint, so we use fetch directly

  try {
    let url = `${origin}/api/miauth/${sessionId}/check`

    let response = await Fetch.fetch(
      url,
      {
        method: #POST,
      },
    )

    let ok = response->Fetch.Response.ok

    if !ok {
      // Log the status code for debugging
      let status = response->Fetch.Response.status
      Console.log2("MiAuth check: Response not OK, status code:", status)
      // If the response is not OK, auth is probably still pending
      Ok({token: None, user: None})
    } else {
      let json = await response->Fetch.Response.json
      let obj = json->JSON.Decode.object

      switch obj {
      | Some(obj) => {
          let token = obj->Dict.get("token")->Option.flatMap(JSON.Decode.string)
          let user = obj->Dict.get("user")

          switch token {
          | Some(t) => {
              Console.log("MiAuth check: Token received successfully")
              Ok({token: Some(t), user})
            }
          | None => {
              Console.log("MiAuth check: Token is None - auth still pending")
              Ok({token: None, user: None})
            }
          }
        }
      | None => {
          Console.log("MiAuth check: Could not decode response as JSON object")
          // If we can't decode the object, return empty result
          Ok({token: None, user: None})
        }
      }
    }
  } catch {
  | error => {
      let msg = switch error->JsExn.fromException {
      | Some(jsExn) => JsExn.message(jsExn)->Option.getOr("Unknown error")
      | None => "Unknown error"
      }
      Console.error2("MiAuth check: Error during fetch", msg)
      handleError(error)
    }
  }
}

// Helper: Open auth URL in same window
@val @scope("window") @scope("location")
external windowLocationAssign: string => unit = "assign"

let openAuthUrl = (authUrl: string): unit => {
  windowLocationAssign(authUrl)
}

// Helper: Open auth URL in new window
@val @scope("window")
external windowOpen: (string, string, string) => Nullable.t<{..}> = "open"

let openAuthUrlInNewWindow = (authUrl: string): unit => {
  let _ = windowOpen(authUrl, "_blank", "width=600,height=800")
}
