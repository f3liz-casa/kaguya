// SPDX-License-Identifier: MPL-2.0

module NoteView = {
  @jsx.component
  let make = (~note: NoteView.t, ~noteHost: option<string>=?) => {
    <NoteCard note ?noteHost />
  }
}

@jsx.component
let make = (~note: JSON.t) => {
  switch NoteDecoder.decode(note) {
  | Some(noteData) => <NoteCard note={noteData} />
  | None => Preact.null
  }
}
