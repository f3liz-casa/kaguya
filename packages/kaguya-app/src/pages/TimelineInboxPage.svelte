<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of TimelineInboxPage.tsx. Aggregates unread notes
  across tracked timelines (lastSeenId-driven), with 1-day silent
  advancement for sources shown long ago. SourceSection is in
  TimelineInboxSection.svelte.

  Not yet mounted at runtime — TimelineInboxPage.tsx remains the
  live page until M5 mount swap.
-->

<script lang="ts">
  import Layout from '../ui/Layout.svelte'
  import * as Backend from '../lib/backend'
  import { CustomTimelines } from '../lib/misskey'
  import { client } from '../domain/auth/appState'
  import { decodeManyFromJson } from '../domain/note/noteDecoder'
  import type { TimelineType } from '../lib/backend'
  import { antennas, lists, channels } from '../domain/timeline/timelineStore'
  import { currentLocale, t } from '../infra/i18n'
  import { svelteSignal } from '../ui/svelteSignal.svelte'
  import TimelineInboxSection, { type TimelineSource } from './TimelineInboxSection.svelte'

  const LAST_SEEN_PREFIX = 'kaguya:lastSeenNoteId:'
  const SHOWN_AT_PREFIX = 'kaguya:timelineInboxShownAt:'
  const ONE_DAY_MS = 86400000

  const localeR = svelteSignal(currentLocale)
  const antennasR = svelteSignal(antennas)
  const listsR = svelteSignal(lists)
  const channelsR = svelteSignal(channels)

  let sources = $state<TimelineSource[]>([])
  let loaded = $state(false)

  const L = $derived((localeR.value, {
    title: t('timeline_inbox.title'),
    loading: t('timeline.loading'),
    empty: t('inbox.empty'),
    timelineHome: t('timeline.home'),
    timelineLocal: t('timeline.local'),
    timelineGlobal: t('timeline.global'),
    timelineHybrid: t('timeline.hybrid'),
  }))

  $effect(() => {
    const currentClient = client.peek()
    if (!currentClient) { loaded = true; return }

    const now = Date.now()

    const candidates: Array<{ storageKey: string; type_: TimelineType; name: string }> = [
      { storageKey: 'home',   type_: 'home',   name: L.timelineHome },
      { storageKey: 'local',  type_: 'local',  name: L.timelineLocal },
      { storageKey: 'global', type_: 'global', name: L.timelineGlobal },
      { storageKey: 'hybrid', type_: 'hybrid', name: L.timelineHybrid },
    ]

    for (const a of antennasR.value) {
      const pair = CustomTimelines.extractIdAndName(a)
      if (pair) candidates.push({ storageKey: `antenna-${pair[0]}`, type_: { kind: 'antenna', id: pair[0] }, name: pair[1] })
    }
    for (const l of listsR.value) {
      const pair = CustomTimelines.extractIdAndName(l)
      if (pair) candidates.push({ storageKey: `list-${pair[0]}`, type_: { kind: 'list', id: pair[0] }, name: pair[1] })
    }
    for (const ch of channelsR.value) {
      const pair = CustomTimelines.extractIdAndName(ch)
      if (pair) candidates.push({ storageKey: `channel-${pair[0]}`, type_: { kind: 'channel', id: pair[0] }, name: pair[1] })
    }

    for (const c of candidates) {
      const shownAtRaw = localStorage.getItem(SHOWN_AT_PREFIX + c.storageKey)
      if (shownAtRaw) {
        const shownAt = parseInt(shownAtRaw, 10)
        if (now - shownAt >= ONE_DAY_MS) {
          localStorage.removeItem(SHOWN_AT_PREFIX + c.storageKey)
        }
      }
    }

    const toDisplay: typeof candidates = []
    const toAutoAdvance: typeof candidates = []

    for (const c of candidates) {
      const hasLastSeen = localStorage.getItem(LAST_SEEN_PREFIX + c.storageKey) !== null
      if (!hasLastSeen) continue
      const shownAtRaw = localStorage.getItem(SHOWN_AT_PREFIX + c.storageKey)
      const wasShownLongAgo = shownAtRaw ? now - parseInt(shownAtRaw, 10) >= ONE_DAY_MS : false
      if (wasShownLongAgo) toAutoAdvance.push(c)
      else toDisplay.push(c)
    }

    let isMounted = true

    void (async () => {
      await Promise.all(
        toAutoAdvance.map(async ({ storageKey, type_ }) => {
          const result = await Backend.fetchTimeline(currentClient, type_, 1)
          if (result.ok) {
            const decoded = decodeManyFromJson(Array.isArray(result.value) ? result.value : [])
            const newestId = decoded[0]?.id
            if (newestId) localStorage.setItem(LAST_SEEN_PREFIX + storageKey, newestId)
          }
          localStorage.removeItem(SHOWN_AT_PREFIX + storageKey)
        }),
      )

      if (!isMounted) return

      if (toDisplay.length === 0) { loaded = true; return }

      const results = await Promise.all(
        toDisplay.map(async ({ storageKey, type_, name }) => {
          const lastSeenId = localStorage.getItem(LAST_SEEN_PREFIX + storageKey)!
          const result = await Backend.fetchTimeline(currentClient, type_, 30, lastSeenId)
          if (!result.ok) return null
          const decoded = decodeManyFromJson(Array.isArray(result.value) ? result.value : [])
          if (decoded.length === 0) return null
          return { storageKey, type_, name, notes: decoded, hasMore: decoded.length >= 30 }
        }),
      )
      if (!isMounted) return
      sources = results.filter((s): s is TimelineSource => s !== null)
      loaded = true
    })()

    return () => { isMounted = false }
  })

  function markRead(source: TimelineSource) {
    const newestId = source.notes[0]?.id
    if (newestId) localStorage.setItem(LAST_SEEN_PREFIX + source.storageKey, newestId)
    localStorage.removeItem(SHOWN_AT_PREFIX + source.storageKey)
    sources = sources.filter((s) => s.storageKey !== source.storageKey)
  }
</script>

<Layout>
  <div class="timeline-inbox-container">
    <div class="inbox-header">
      <h2 class="inbox-title">{L.title}</h2>
    </div>

    {#if !loaded}
      <div class="timeline-loading-more"><p>{L.loading}</p></div>
    {/if}

    {#if loaded && sources.length === 0}
      <div class="inbox-empty">
        <div class="inbox-empty-icon">✨</div>
        <p class="inbox-empty-text">{L.empty}</p>
      </div>
    {/if}

    {#each sources as source (source.storageKey)}
      <TimelineInboxSection {source} onMarkRead={markRead} />
    {/each}
  </div>
</Layout>
