<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of HomePageTimeline. Hosts the timeline selector — the
  list of standard + custom (antenna / list / channel / feed)
  timelines — and renders the selected one through Timeline.svelte.
  Not yet mounted at runtime.
-->

<script lang="ts">
  import { client } from '../auth/appState'
  import { antennas, lists, channels, feeds } from './timelineStore'
  import { CustomTimelines } from '../../lib/misskey'
  import { currentLocale, t } from '../../infra/i18n'
  import { svelteSignal } from '../../ui/svelteSignal.svelte'
  import Timeline, { type TimelineItem, getItemDisplayName } from './Timeline.svelte'

  const clientR = svelteSignal(client)
  const antennasR = svelteSignal(antennas)
  const listsR = svelteSignal(lists)
  const channelsR = svelteSignal(channels)
  const feedsR = svelteSignal(feeds)
  const localeR = svelteSignal(currentLocale)

  const standardTimelines: TimelineItem[] = [
    { type_: 'home', nameKey: 'timeline.home', category: 'standard' },
    { type_: 'local', nameKey: 'timeline.local', category: 'standard' },
    { type_: 'global', nameKey: 'timeline.global', category: 'standard' },
    { type_: 'hybrid', nameKey: 'timeline.hybrid', category: 'standard' },
    { type_: 'local', nameKey: 'timeline.filtered', category: 'standard', reactionFiltered: true },
  ]

  // Mirror of Timeline.tsx's extractListIdAndName — Bluesky lists use
  // {uri, name}, Misskey lists use {id, name}.
  function extractListIdAndName(item: unknown): [string, string] | undefined {
    if (item && typeof item === 'object') {
      const o = item as { uri?: unknown; name?: unknown }
      if (typeof o.uri === 'string' && typeof o.name === 'string') return [o.uri, o.name]
    }
    return CustomTimelines.extractIdAndName(item)
  }

  function extractFeedItem(item: unknown): { uri: string; displayName: string; pinned: boolean } | undefined {
    if (!item || typeof item !== 'object') return undefined
    const o = item as { uri?: unknown; displayName?: unknown; pinned?: unknown }
    if (typeof o.uri !== 'string' || typeof o.displayName !== 'string') return undefined
    return { uri: o.uri, displayName: o.displayName, pinned: o.pinned === true }
  }

  let selectedTimeline = $state<TimelineItem>(standardTimelines[0])

  const allTimelines = $derived.by<TimelineItem[]>(() => {
    if (!clientR.value) return standardTimelines
    void localeR.value // re-render on locale switch (display names cache through getItemDisplayName)

    const customItems: TimelineItem[] = []
    antennasR.value.forEach((a) => {
      const pair = CustomTimelines.extractIdAndName(a)
      if (pair) customItems.push({ type_: { kind: 'antenna', id: pair[0] }, nameKey: 'timeline.antenna', customName: pair[1], category: 'antenna' })
    })
    listsR.value.forEach((l) => {
      const pair = extractListIdAndName(l)
      if (pair) customItems.push({ type_: { kind: 'list', id: pair[0] }, nameKey: 'timeline.list', customName: pair[1], category: 'list' })
    })
    channelsR.value.forEach((ch) => {
      const pair = CustomTimelines.extractIdAndName(ch)
      if (pair) customItems.push({ type_: { kind: 'channel', id: pair[0] }, nameKey: 'timeline.channel', customName: pair[1], category: 'channel' })
    })
    const pinnedFeedItems: TimelineItem[] = []
    const savedFeedItems: TimelineItem[] = []
    feedsR.value.forEach((f) => {
      const view = extractFeedItem(f)
      if (!view) return
      const item: TimelineItem = { type_: { kind: 'feed', id: view.uri }, nameKey: 'timeline.feed', customName: view.displayName, category: 'feed' }
      ;(view.pinned ? pinnedFeedItems : savedFeedItems).push(item)
    })
    return [...standardTimelines, ...customItems, ...pinnedFeedItems, ...savedFeedItems]
  })

  function onSelect(item: TimelineItem) {
    selectedTimeline = item
  }
</script>

<Timeline
  timelineType={selectedTimeline.type_}
  name={getItemDisplayName(selectedTimeline, t)}
  selector={{ allTimelines, selectedTimeline, onSelect }}
  reactionFiltered={selectedTimeline.reactionFiltered}
/>
