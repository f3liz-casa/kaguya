// SPDX-License-Identifier: MPL-2.0
// NoteOps.res - Operations on notes (prefetching, etc.)

let rec prefetchImages = (note: NoteView.t): unit => {
  // 1. Prefetch user avatar
  if note.user.avatarUrl != "" {
    ImagePreloader.preloadImage(note.user.avatarUrl)
  }

  // 2. Prefetch file images
  note.files->Array.forEach(file => {
    if FileView.isImage(file) {
      ImagePreloader.preloadImage(FileView.displayUrl(file))
    }
  })

  // 3. Prefetch reaction emojis
  note.reactionEmojis
  ->Dict.valuesToArray
  ->Array.forEach(url => {
    if url != "" {
      ImagePreloader.preloadImage(url)
    }
  })

  // 4. Prefetch renote images recursively
  note.renote->Option.forEach(prefetchImages)
}
