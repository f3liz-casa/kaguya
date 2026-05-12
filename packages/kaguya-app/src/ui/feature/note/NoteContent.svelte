<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of NoteContent.tsx. CW toggle + body text via
  ContentRenderer + optional poll. Not yet mounted at runtime.
-->

<script lang="ts">
  import type { NoteView } from '../../../domain/note/noteView'
  import ContentRenderer from '../../content/ContentRenderer.svelte'
  import NotePoll from './NotePoll.svelte'
  import { currentLocale, t } from '../../../infra/i18n'
  import { svelteSignal } from '../../svelteSignal.svelte'

  type Props = {
    note: NoteView
    showContent: boolean
    onToggleCw: () => void
    contextHost?: string
  }
  let { note, showContent, onToggleCw, contextHost }: Props = $props()

  const localeR = svelteSignal(currentLocale)
  const L = $derived((localeR.value, {
    collapseCw: t('note.collapse_cw'),
    revealCw: t('note.reveal_cw'),
  }))
</script>

<div class="note-content" role="region" aria-label="Note content">
  {#if note.cw !== undefined}
    <p class="content-warning" role="alert">{note.cw}</p>
    <button
      class="cw-toggle secondary outline"
      type="button"
      aria-label={showContent ? L.collapseCw : L.revealCw}
      aria-expanded={showContent}
      onclick={onToggleCw}
    >
      {showContent ? L.collapseCw : L.revealCw}
    </button>
  {/if}
  {#if showContent && note.text}
    <div class="note-text">
      <ContentRenderer text={note.text} contentType={note.contentType} facets={note.facets} contextHost={contextHost} />
    </div>
  {/if}
  {#if showContent && note.poll}
    <NotePoll noteId={note.id} poll={note.poll} />
  {/if}
</div>
