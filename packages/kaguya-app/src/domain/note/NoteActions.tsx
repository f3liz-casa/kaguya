// SPDX-License-Identifier: MPL-2.0

import { useState } from 'preact/hooks'
import { useLocation } from '../../ui/router'
import type { ReactionAcceptance } from '../../infra/sharedTypes'
import { client, isLoggedIn, isReadOnlyMode } from '../auth/appState'
import * as Backend from '../../lib/backend'
import { showSuccess, showError } from '../../ui/toastState'
import { EmojiPicker } from '../emoji/EmojiPicker'
import { t } from '../../infra/i18n'
import { defaultRenoteVisibility } from '../../ui/preferencesStore'

type Props = {
  noteId: string
  noteHost: string
  reactionAcceptance?: ReactionAcceptance
  isFavorited?: boolean
}

export function NoteActions({ noteId, noteHost, reactionAcceptance, isFavorited = false }: Props) {
  const [, navigate] = useLocation()
  const [isRenoting, setIsRenoting] = useState(false)
  const [showEmojiPicker, setShowEmojiPicker] = useState(false)
  const [favorited, setFavorited] = useState(isFavorited)
  const [isFavoriting, setIsFavoriting] = useState(false)
  const loggedIn = isLoggedIn.value
  const readOnly = isReadOnlyMode()

  function handleReply() {
    navigate(`/notes/${encodeURIComponent(noteId)}/${noteHost}`)
  }

  function handleRenote() {
    if (!loggedIn || readOnly || isRenoting) return
    void (async () => {
      setIsRenoting(true)
      const currentClient = client.value
      if (currentClient) {
        const result = await Backend.createNote(currentClient, undefined, { renoteId: noteId, visibility: defaultRenoteVisibility.value })
        if (result.ok) showSuccess(t('note.renoted'))
        else showError(t('note.renote_failed'))
      } else {
        showError(t('error.not_connected'))
      }
      setIsRenoting(false)
    })()
  }

  function handleFavorite() {
    if (!loggedIn || readOnly || isFavoriting) return
    void (async () => {
      setIsFavoriting(true)
      const currentClient = client.value
      if (currentClient) {
        if (favorited) {
          const result = await Backend.unfavourite(currentClient, noteId)
          if (result.ok) {
            setFavorited(false)
            showSuccess(t('note.unfavorited'))
          } else {
            showError(t('note.favorite_failed'))
          }
        } else {
          const result = await Backend.favourite(currentClient, noteId)
          if (result.ok) {
            setFavorited(true)
            showSuccess(t('note.favorited'))
          } else {
            showError(t('note.favorite_failed'))
          }
        }
      } else {
        showError(t('error.not_connected'))
      }
      setIsFavoriting(false)
    })()
  }

  function handleEmojiSelect(emoji: string) {
    setShowEmojiPicker(false)
    void (async () => {
      const currentClient = client.value
      if (currentClient) {
        const result = await Backend.react(currentClient, noteId, emoji)
        if (!result.ok) showError(t('note.reaction_failed'))
      }
    })()
  }

  return (
    <div class="note-actions">
      <button class="note-action-btn" onClick={handleReply} title={t('note.reply')} type="button" aria-label={t('note.reply')}>
        <iconify-icon icon="tabler:arrow-back-up" />
      </button>
      <button
        class={`note-action-btn${isRenoting ? ' loading' : ''}`}
        onClick={handleRenote}
        title={t('note.renote')}
        type="button"
        aria-label={t('note.renote')}
        disabled={isRenoting || !loggedIn || readOnly}
      >
        <iconify-icon icon="tabler:repeat" />
      </button>
      {loggedIn && !readOnly && (
        <>
          <button
            class="note-action-btn"
            onClick={() => setShowEmojiPicker(true)}
            title={t('note.reaction')}
            type="button"
            aria-label={t('note.add_reaction')}
          >
            <iconify-icon icon="tabler:plus" />
          </button>
          {showEmojiPicker && (
            <EmojiPicker
              onSelect={handleEmojiSelect}
              onClose={() => setShowEmojiPicker(false)}
              reactionAcceptance={reactionAcceptance}
            />
          )}
        </>
      )}
      {loggedIn && !readOnly && (
        <button
          class={`note-action-btn${favorited ? ' note-action-active' : ''}`}
          onClick={handleFavorite}
          title={favorited ? t('note.unfavorite') : t('note.favorite')}
          type="button"
          aria-label={favorited ? t('note.unfavorite') : t('note.favorite')}
          aria-pressed={favorited}
          disabled={isFavoriting}
        >
          <iconify-icon icon={favorited ? 'tabler:bookmark-filled' : 'tabler:bookmark'} />
        </button>
      )}
      <button class="note-action-btn note-action-more" title={t('note.more')} type="button" aria-label={t('note.more')}>
        <iconify-icon icon="tabler:dots" />
      </button>
    </div>
  )
}
