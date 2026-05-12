<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of TimelineInboxPage's inline SourceSection sub-
  component. One section per tracked timeline source, with
  IntersectionObserver-driven shownAt recording and a mark-read
  button. Not yet mounted at runtime.
-->

<script lang="ts">
  import type { NoteView } from '../domain/note/noteView'
  import type { TimelineType } from '../lib/backend'
  import { instanceName } from '../domain/auth/appState'
  import Note from '../ui/feature/note/Note.svelte'
  import { shouldShowNote, userFilters } from '../domain/user/userFilterStore'
  import { currentLocale, t } from '../infra/i18n'
  import { svelteSignal } from '../ui/svelteSignal.svelte'

  const SHOWN_AT_PREFIX = 'kaguya:timelineInboxShownAt:'

  export type TimelineSource = {
    storageKey: string
    type_: TimelineType
    name: string
    notes: NoteView[]
    hasMore: boolean
  }

  function timelineIcon(type_: TimelineType): string {
    if (typeof type_ === 'string') {
      switch (type_) {
        case 'home':   return 'tabler:home'
        case 'local':  return 'tabler:building-community'
        case 'global': return 'tabler:world'
        case 'hybrid': return 'tabler:universe'
        default:       return 'tabler:timeline'
      }
    }
    switch (type_.kind) {
      case 'antenna': return 'tabler:antenna'
      case 'list':    return 'tabler:list'
      case 'channel': return 'tabler:message-chatbot'
      default:        return 'tabler:timeline'
    }
  }

  type Props = { source: TimelineSource; onMarkRead: (source: TimelineSource) => void }
  let { source, onMarkRead }: Props = $props()

  const instanceR = svelteSignal(instanceName)
  const localeR = svelteSignal(currentLocale)
  const userFiltersR = svelteSignal(userFilters)

  let sectionEl = $state<HTMLElement | null>(null)

  const L = $derived((localeR.value, {
    markRead: t('inbox.mark_read'),
  }))

  $effect(() => {
    void source.storageKey
    const el = sectionEl
    if (!el) return
    const shownAtKey = SHOWN_AT_PREFIX + source.storageKey
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) {
          if (!localStorage.getItem(shownAtKey)) {
            localStorage.setItem(shownAtKey, String(Date.now()))
          }
          observer.disconnect()
        }
      },
      { threshold: 0.1 },
    )
    observer.observe(el)
    return () => observer.disconnect()
  })

  const visibleNotes = $derived((userFiltersR.value, source.notes.filter(shouldShowNote)))
  const count = $derived(source.hasMore ? '30+' : String(source.notes.length))
</script>

<section bind:this={sectionEl} class="timeline-inbox-source">
  <div class="timeline-inbox-source-header">
    <iconify-icon icon={timelineIcon(source.type_)} class="timeline-inbox-source-icon"></iconify-icon>
    <span class="timeline-inbox-source-name">{source.name}</span>
    <span class="inbox-group-count">{count}</span>
    <button
      class="timeline-inbox-mark-read-btn"
      type="button"
      title={L.markRead}
      aria-label={L.markRead}
      onclick={() => onMarkRead(source)}
    >
      <iconify-icon icon="tabler:check"></iconify-icon>
    </button>
  </div>
  <div class="timeline-notes">
    {#each visibleNotes as note (note.id)}
      <Note {note} noteHost={instanceR.value} />
    {/each}
  </div>
</section>
