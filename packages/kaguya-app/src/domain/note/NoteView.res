// SPDX-License-Identifier: MPL-2.0

type rec t = {
  id: string,
  user: UserView.t,
  text: option<string>,
  cw: option<string>,
  createdAt: string,
  files: array<FileView.t>,
  reactions: Dict.t<int>,
  reactionEmojis: Dict.t<string>,
  myReaction: option<string>,
  reactionAcceptance: option<SharedTypes.reactionAcceptance>,
  renote: option<t>, // Recursive for renotes
  replyId: option<string>,
  reply: option<t>, // Parent note if this is a reply
  uri: option<string>, // ActivityPub URI (set for federated notes, absent for local)
}

// Computed Properties

let relativeTime = (note: t): string => {
  TimeFormat.formatRelativeTime(note.createdAt)
}

let isPureRenote = (note: t): bool => {
  note.text->Option.isNone && note.files->Array.length == 0 && note.renote->Option.isSome
}

let hasContentWarning = (note: t): bool => {
  note.cw->Option.isSome
}

let hasMedia = (note: t): bool => {
  note.files->Array.length > 0
}

let imageFiles = (note: t): array<FileView.t> => {
  note.files->Array.filter(FileView.isImage)
}

// Count total reactions
let reactionCount = (note: t): int => {
  note.reactions
  ->Dict.valuesToArray
  ->Array.reduce(0, (acc, count) => acc + count)
}

let hasUserReacted = (note: t): bool => {
  note.myReaction->Option.isSome
}
