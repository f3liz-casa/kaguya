// SPDX-License-Identifier: MPL-2.0

import type { NoteView } from './noteView'
import { NoteCard } from './NoteCard'
import { decode } from './noteDecoder'

type NoteViewProps = {
  note: NoteView
  noteHost?: string
}

export function NoteViewComponent({ note, noteHost }: NoteViewProps) {
  return <NoteCard note={note} noteHost={noteHost} />
}

type NoteProps = {
  note: unknown
}

export function Note({ note }: NoteProps) {
  const noteData = decode(note)
  if (!noteData) return null
  return <NoteCard note={noteData} />
}
