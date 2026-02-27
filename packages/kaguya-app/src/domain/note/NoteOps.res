// SPDX-License-Identifier: MPL-2.0

let rec collectImageUrls = (note: NoteView.t): array<string> => {
  let avatar = note.user.avatarUrl != "" ? [note.user.avatarUrl] : []

  let fileUrls =
    note.files
    ->Array.filter(FileView.isImage)
    ->Array.map(FileView.displayUrl)

  let emojiUrls =
    note.reactionEmojis
    ->Dict.valuesToArray
    ->Array.filter(url => url != "")

  let renoteUrls =
    note.renote
    ->Option.map(collectImageUrls)
    ->Option.getOr([])

  Array.flat([avatar, fileUrls, emojiUrls, renoteUrls])
}

let prefetchImages = (note: NoteView.t): unit => {
  collectImageUrls(note)->Array.forEach(ImagePreloader.preloadImage)
}

let prefetchImagesAsync = (note: NoteView.t): promise<unit> => {
  switch collectImageUrls(note) {
  | [] => Promise.resolve()
  | urls => urls->Array.map(ImagePreloader.preloadImageAsync)->Promise.all->Promise.thenResolve(_ => ())
  }
}

