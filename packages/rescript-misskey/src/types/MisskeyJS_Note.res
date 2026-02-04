// Note entity types

open MisskeyJS_Common

// Poll choice structure
type pollChoice = {
  text: string,
  votes: int,
  isVoted: bool,
}

// Poll structure
type poll = {
  multiple: bool,
  expiresAt: option<dateString>,
  choices: array<pollChoice>,
}

// Recursive note type
type rec note = {
  id: id,
  createdAt: dateString,
  userId: id,
  user: JSON.t, // MisskeyJS_User.userLite
  text: option<string>,
  cw: option<string>,
  visibility: visibility,
  localOnly: option<bool>,
  reactionAcceptance: option<
    [
      | #likeOnly
      | #likeOnlyForRemote
      | #nonSensitiveOnly
      | #nonSensitiveOnlyForLocalLikeOnlyForRemote
    ],
  >,
  renoteCount: int,
  repliesCount: int,
  reactions: Dict.t<int>,
  reactionEmojis: Dict.t<string>,
  emojis: array<emoji>,
  fileIds: array<id>,
  files: array<JSON.t>, // MisskeyJS_Drive.driveFile
  replyId: option<id>,
  renoteId: option<id>,
  reply: option<note>,
  renote: option<note>,
  uri: option<string>,
  url: option<string>,
  mentions: option<array<id>>,
  visibleUserIds: option<array<id>>,
  channelId: option<id>,
  channel: option<JSON.t>,
  tags: option<array<string>>,
  poll: option<poll>,
  myReaction: option<string>,
}

type t = note

// Check if a note is a pure renote (no additional content)
let isPureRenote = (note: note): bool => {
  note.text == None && note.fileIds->Array.length == 0 && note.poll == None && note.renote != None
}
