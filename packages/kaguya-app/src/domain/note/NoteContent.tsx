// SPDX-License-Identifier: MPL-2.0

import type { NoteView } from './noteView'
import { ContentRenderer } from '../../ui/content/ContentRenderer'
import { NotePoll } from './NotePoll'
import { t } from '../../infra/i18n'

type Props = {
  note: NoteView
  showContent: boolean
  onToggleCw: () => void
  contextHost?: string
}

export function NoteContent({ note, showContent, onToggleCw, contextHost }: Props) {
  return (
    <div class="note-content" role="region" aria-label="Note content">
      {note.cw !== undefined && (
        <>
          <p class="content-warning" role="alert">{note.cw}</p>
          <button
            class="cw-toggle secondary outline"
            onClick={onToggleCw}
            aria-label={showContent ? t('note.collapse_cw') : t('note.reveal_cw')}
            aria-expanded={showContent}
            type="button"
          >
            {showContent ? t('note.collapse_cw') : t('note.reveal_cw')}
          </button>
        </>
      )}
      {showContent && note.text && (
        <div class="note-text">
          <ContentRenderer text={note.text} contentType={note.contentType} facets={note.facets} contextHost={contextHost} />
        </div>
      )}
      {showContent && note.poll && <NotePoll noteId={note.id} poll={note.poll} />}
    </div>
  )
}
