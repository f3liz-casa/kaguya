// SPDX-License-Identifier: MPL-2.0

import { useState } from 'preact/hooks'
import { useLocation } from '../../ui/router'
import { Link } from '../../ui/router'
import type { NoteView } from './noteView'
import { isPureRenote, hasContentWarning } from './noteView'
import type { UserView } from '../user/userView'
import { instanceName } from '../auth/appState'
import { NoteHeader } from './NoteHeader'
import { NoteContent } from './NoteContent'
import { NoteActions } from './NoteActions'
import { ImageGallery } from './ImageGallery'
import { ReactionBar } from '../../ui/ReactionBar'
import { ContentRenderer } from '../../ui/content/ContentRenderer'
import { proxyAvatarUrl } from '../../infra/mediaProxy'
import { formatRelativeTime } from '../../infra/timeFormat'
import { t } from '../../infra/i18n'

function isInteractiveClick(e: MouseEvent): boolean {
  const target = e.target as HTMLElement
  const tagName = target.tagName
  const interactive = tagName === 'A' || tagName === 'BUTTON' || tagName === 'IMG' || tagName === 'INPUT'
  const closest = target.closest('a, button, .reaction-button, .lightbox-overlay, .sensitive-overlay, .image-attachment')
  return interactive || !!closest
}

type Props = {
  note: NoteView
  noteHost?: string
}

export function NoteCard({ note, noteHost }: Props) {
  const [, navigate] = useLocation()
  const localHost = instanceName.value
  const effectiveHost = noteHost ?? localHost
  const pureRenote = isPureRenote(note)

  // For pure renotes, the displayed note is the renoted one
  const displayNote = pureRenote ? note.renote! : note
  const [showContent, setShowContent] = useState(!hasContentWarning(displayNote))

  function handleNoteClick(e: MouseEvent) {
    if (!isInteractiveClick(e)) {
      navigate(`/notes/${encodeURIComponent(displayNote.id)}/${effectiveHost}`)
    }
  }

  return (
    <article
      class="note note-clickable"
      role="article"
      aria-label={`${displayNote.user.name}${t('note.from_user')}`}
      onClick={handleNoteClick}
    >
      {pureRenote && (
        <RenoteHeader user={note.user} createdAt={note.createdAt} contextHost={effectiveHost} />
      )}

      {displayNote.reply && (
        <div class="note-reply-parent">
          <div class="note-reply-connector" />
          <div class="note-reply-parent-content">
            <NoteHeader user={displayNote.reply.user} createdAt={displayNote.reply.createdAt} noteId={displayNote.reply.id} contextHost={effectiveHost} />
            {displayNote.reply.text && (
              <div class="note-text">
                <ContentRenderer text={displayNote.reply.text} contentType={displayNote.reply.contentType} facets={displayNote.reply.facets} contextHost={effectiveHost} />
              </div>
            )}
          </div>
        </div>
      )}

      <NoteHeader user={displayNote.user} createdAt={displayNote.createdAt} noteId={displayNote.id} contextHost={effectiveHost} />
      <NoteContent note={displayNote} showContent={showContent} onToggleCw={() => setShowContent(v => !v)} contextHost={effectiveHost} />
      <ImageGallery files={displayNote.files} />
      <ReactionBar
        noteId={displayNote.id}
        reactions={displayNote.reactions}
        reactionEmojis={displayNote.reactionEmojis}
        myReaction={displayNote.myReaction}
        reactionAcceptance={displayNote.reactionAcceptance}
      />
      <NoteActions noteId={displayNote.id} noteHost={effectiveHost} reactionAcceptance={displayNote.reactionAcceptance} />
    </article>
  )
}

function RenoteHeader({ user, createdAt, contextHost }: { user: UserView; createdAt: string; contextHost: string }) {
  const userHost = user.host ?? contextHost
  const userPath = `/@${user.username}@${userHost}`
  const relativeTime = formatRelativeTime(createdAt)

  return (
    <div class="renote-indicator" role="status" aria-label={`${user.name}${t('note.user_renoted')}`}>
      <Link href={userPath} class="renote-indicator-avatar-link">
        {user.avatarUrl ? (
          <img
            class="renote-indicator-avatar"
            src={proxyAvatarUrl(user.avatarUrl)}
            alt=""
            loading="lazy"
          />
        ) : (
          <div class="renote-indicator-avatar renote-indicator-avatar-placeholder" />
        )}
      </Link>
      <iconify-icon icon="tabler:repeat" class="renote-indicator-icon" />
      <small class="renote-indicator-text">
        <Link href={userPath} class="renote-indicator-name">
          <ContentRenderer text={user.name} parseSimple />
        </Link>
        {t('note.user_renoted')}
      </small>
      <time class="renote-indicator-time" dateTime={createdAt}>{relativeTime}</time>
    </div>
  )
}
