<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of NoteActions.tsx. Reply / renote / reaction / favorite
  action bar; embeds EmojiPicker.svelte for reaction selection. Not
  yet mounted at runtime.
-->

<script lang="ts">
  import type { ReactionAcceptance } from '../../../infra/sharedTypes'
  import { client, isLoggedIn, isReadOnlyMode } from '../../../domain/auth/appState'
  import * as Backend from '../../../lib/backend'
  import { showSuccess, showError } from '../../toastState'
  import EmojiPicker from '../emoji/EmojiPicker.svelte'
  import { currentLocale, t } from '../../../infra/i18n'
  import { defaultRenoteVisibility } from '../../preferencesStore'
  import { svelteSignal } from '../../svelteSignal.svelte'
  import { navigate } from '../../svelteRouter'

  type Props = {
    noteId: string
    noteHost: string
    reactionAcceptance?: ReactionAcceptance
    isFavorited?: boolean
  }
  let { noteId, noteHost, reactionAcceptance, isFavorited = false }: Props = $props()

  const localeR = svelteSignal(currentLocale)
  const loggedInR = svelteSignal(isLoggedIn)

  let isRenoting = $state(false)
  let showEmojiPicker = $state(false)
  let favorited = $state(isFavorited)
  let isFavoriting = $state(false)

  const readOnly = $derived((loggedInR.value, isReadOnlyMode()))

  const L = $derived((localeR.value, {
    reply: t('note.reply'),
    renote: t('note.renote'),
    renoted: t('note.renoted'),
    renoteFailed: t('note.renote_failed'),
    notConnected: t('error.not_connected'),
    reaction: t('note.reaction'),
    addReaction: t('note.add_reaction'),
    favorite: t('note.favorite'),
    unfavorite: t('note.unfavorite'),
    favorited: t('note.favorited'),
    unfavorited: t('note.unfavorited'),
    favoriteFailed: t('note.favorite_failed'),
    reactionFailed: t('note.reaction_failed'),
    more: t('note.more'),
  }))

  function handleReply() {
    navigate(`/notes/${encodeURIComponent(noteId)}/${noteHost}`)
  }

  function handleRenote() {
    if (!loggedInR.value || readOnly || isRenoting) return
    void (async () => {
      isRenoting = true
      const currentClient = client.peek()
      if (currentClient) {
        const result = await Backend.createNote(currentClient, undefined, { renoteId: noteId, visibility: defaultRenoteVisibility.peek() })
        if (result.ok) showSuccess(L.renoted)
        else showError(L.renoteFailed)
      } else {
        showError(L.notConnected)
      }
      isRenoting = false
    })()
  }

  function handleFavorite() {
    if (!loggedInR.value || readOnly || isFavoriting) return
    void (async () => {
      isFavoriting = true
      const currentClient = client.peek()
      if (currentClient) {
        if (favorited) {
          const result = await Backend.unfavourite(currentClient, noteId)
          if (result.ok) { favorited = false; showSuccess(L.unfavorited) }
          else showError(L.favoriteFailed)
        } else {
          const result = await Backend.favourite(currentClient, noteId)
          if (result.ok) { favorited = true; showSuccess(L.favorited) }
          else showError(L.favoriteFailed)
        }
      } else {
        showError(L.notConnected)
      }
      isFavoriting = false
    })()
  }

  function handleEmojiSelect(emoji: string) {
    showEmojiPicker = false
    void (async () => {
      const currentClient = client.peek()
      if (currentClient) {
        const result = await Backend.react(currentClient, noteId, emoji)
        if (!result.ok) showError(L.reactionFailed)
      }
    })()
  }
</script>

<div class="note-actions">
  <button class="note-action-btn" type="button" title={L.reply} aria-label={L.reply} onclick={handleReply}>
    <iconify-icon icon="tabler:arrow-back-up"></iconify-icon>
  </button>
  <button
    class={`note-action-btn${isRenoting ? ' loading' : ''}`}
    type="button"
    title={L.renote}
    aria-label={L.renote}
    disabled={isRenoting || !loggedInR.value || readOnly}
    onclick={handleRenote}
  >
    <iconify-icon icon="tabler:repeat"></iconify-icon>
  </button>
  {#if loggedInR.value && !readOnly}
    <button
      class="note-action-btn"
      type="button"
      title={L.reaction}
      aria-label={L.addReaction}
      onclick={() => { showEmojiPicker = true }}
    >
      <iconify-icon icon="tabler:plus"></iconify-icon>
    </button>
    {#if showEmojiPicker}
      <EmojiPicker
        onSelect={handleEmojiSelect}
        onClose={() => { showEmojiPicker = false }}
        {reactionAcceptance}
      />
    {/if}
  {/if}
  {#if loggedInR.value && !readOnly}
    <button
      class={`note-action-btn${favorited ? ' note-action-active' : ''}`}
      type="button"
      title={favorited ? L.unfavorite : L.favorite}
      aria-label={favorited ? L.unfavorite : L.favorite}
      aria-pressed={favorited}
      disabled={isFavoriting}
      onclick={handleFavorite}
    >
      <iconify-icon icon={favorited ? 'tabler:bookmark-filled' : 'tabler:bookmark'}></iconify-icon>
    </button>
  {/if}
  <button class="note-action-btn note-action-more" type="button" title={L.more} aria-label={L.more}>
    <iconify-icon icon="tabler:dots"></iconify-icon>
  </button>
</div>
