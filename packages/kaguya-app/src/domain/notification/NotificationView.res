// SPDX-License-Identifier: MPL-2.0

type notificationType =
  | Follow
  | Mention
  | Reply
  | Renote
  | Quote
  | Reaction
  | PollEnded
  | ReceiveFollowRequest
  | FollowRequestAccepted
  | AchievementEarned
  | CreateToken
  | App
  | Unknown(string)

type t = {
  id: string,
  type_: notificationType,
  createdAt: string,
  userId: option<string>,
  userName: option<string>,
  userUsername: option<string>,
  userHost: option<string>,
  userAvatarUrl: option<string>,
  noteId: option<string>,
  noteText: option<string>,
  reaction: option<string>,
  reactionUrl: option<string>,
  body: option<string>,
}

let parseType = (typeStr: string): notificationType => {
  switch typeStr {
  | "follow" => Follow
  | "mention" => Mention
  | "reply" => Reply
  | "renote" => Renote
  | "quote" => Quote
  | "reaction" => Reaction
  | "pollEnded" => PollEnded
  | "receiveFollowRequest" => ReceiveFollowRequest
  | "followRequestAccepted" => FollowRequestAccepted
  | "achievementEarned" => AchievementEarned
  | "createToken" => CreateToken
  | "app" => App
  | other => Unknown(other)
  }
}

let typeLabel = (type_: notificationType): string => {
  switch type_ {
  | Follow => "フォロー"
  | Mention => "メンション"
  | Reply => "返信"
  | Renote => "リノート"
  | Quote => "引用"
  | Reaction => "リアクション"
  | PollEnded => "投票終了"
  | ReceiveFollowRequest => "フォローリクエスト"
  | FollowRequestAccepted => "フォロー承認"
  | AchievementEarned => "実績"
  | CreateToken => "トークン発行"
  | App => "アプリ"
  | Unknown(_) => "通知"
  }
}

let typeIcon = (type_: notificationType): string => {
  switch type_ {
  | Follow => "👤"
  | Mention => "💬"
  | Reply => "💭"
  | Renote => "🔁"
  | Quote => "📝"
  | Reaction => "⭐"
  | PollEnded => "📊"
  | ReceiveFollowRequest => "🔔"
  | FollowRequestAccepted => "✅"
  | AchievementEarned => "🏆"
  | CreateToken => "🔑"
  | App => "📱"
  | Unknown(_) => "🔔"
  }
}

let fullHandle = (notif: t): string => {
  switch (notif.userUsername, notif.userHost) {
  | (Some(u), Some(h)) => "@" ++ u ++ "@" ++ h
  | (Some(u), None) => "@" ++ u
  | _ => ""
  }
}

// Helper to safely get string from JSON object
let getStr = (obj: Dict.t<JSON.t>, key: string): option<string> => {
  obj->Dict.get(key)->Option.flatMap(v => {
    switch v {
    | JSON.Null => None
    | _ => JSON.Decode.string(v)
    }
  })
}

// Decode notification from JSON
let decode = (json: JSON.t): option<t> => {
  switch json->JSON.Decode.object {
  | Some(obj) => {
      let id = getStr(obj, "id")->Option.getOr("")
      let typeStr = getStr(obj, "type")->Option.getOr("")

      if id == "" || typeStr == "" {
        None
      } else {
        // Extract user info
        let userObj = obj->Dict.get("user")->Option.flatMap(JSON.Decode.object)
        let userName = userObj->Option.flatMap(u => {
          switch getStr(u, "name") {
          | Some(n) if n != "" => Some(n)
          | _ => getStr(u, "username")
          }
        })
        let userId = userObj->Option.flatMap(u => getStr(u, "id"))
        let userUsername = userObj->Option.flatMap(u => getStr(u, "username"))
        let userHost = userObj->Option.flatMap(u => getStr(u, "host"))
        let userAvatarUrl = userObj->Option.flatMap(u => getStr(u, "avatarUrl"))

        // Extract note info and cache emojis
        let noteObj = obj->Dict.get("note")->Option.flatMap(JSON.Decode.object)
        let noteId = noteObj->Option.flatMap(n => getStr(n, "id"))
        let noteText = noteObj->Option.flatMap(n => getStr(n, "text"))

        // Cache emojis from note for MFM rendering
        noteObj->Option.forEach(n => EmojiOps.extractAndCache(n))

        // Extract reaction and its URL
        let reaction = getStr(obj, "reaction")
        let reactionEmojis =
          noteObj
          ->Option.flatMap(n => n->Dict.get("reactionEmojis"))
          ->Option.flatMap(JSON.Decode.object)
          ->Option.map(EmojiOps.extractFromJsonDict)
          ->Option.getOr(Dict.make())
        let reactionUrl = reaction->Option.flatMap(r =>
          if EmojiOps.isUnicodeEmoji(r) {
            None
          } else {
            EmojiOps.getEmojiUrl(r, reactionEmojis)
          }
        )

        // Extract body or achievement info
        let body = switch typeStr {
        | "achievementEarned" => getStr(obj, "achievement")
        | _ => getStr(obj, "body")
        }

        Some({
          id,
          type_: parseType(typeStr),
          createdAt: getStr(obj, "createdAt")->Option.getOr(""),
          userId,
          userName,
          userUsername,
          userHost,
          userAvatarUrl,
          noteId,
          noteText,
          reaction,
          reactionUrl,
          body,
        })
      }
    }
  | None => None
  }
}
