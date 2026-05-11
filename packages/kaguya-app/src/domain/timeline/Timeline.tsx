// SPDX-License-Identifier: MPL-2.0

import { Fragment } from 'preact'
import { useState, useEffect, useRef } from 'preact/hooks'
import type { TimelineType, BackendSubscription } from '../../lib/backend'
import * as Backend from '../../lib/backend'
import { CustomTimelines } from '../../lib/misskey'
import { client, authState } from '../auth/appState'
import { homeTimelineInitial, antennas, lists, channels, feeds } from './timelineStore'
import { decode as decodeNote, decodeManyFromJson } from '../note/noteDecoder'
import { prefetchNoteImages } from '../note/noteOps'
import type { NoteView } from '../note/noteView'
import { isNsfw } from '../note/noteView'
import { NoteViewComponent } from '../note/Note'
import { useSignalEffect } from '@preact/signals'
import { isQuiet as isQuietSignal, streamingEnabled, hideNsfw } from '../../ui/preferencesStore'
import { shouldShowNote, userFilters } from '../user/userFilterStore'
import { filterConfig, passesFilter, initFilteredTimeline, loadCachedNotes, saveCachedNotes } from './filteredTimelineStore'
import { t } from '../../infra/i18n'

type TimelineState =
  | { tag: 'Loading' }
  | { tag: 'Loaded'; notes: NoteView[]; lastPostId: string | undefined; hasMore: boolean; isLoadingMore: boolean; isStreaming: boolean; loadMoreError: boolean; loadMoreRetries: number }
  | { tag: 'Error'; message: string }

function getLastNoteId(notes: NoteView[]): string | undefined {
  return notes[notes.length - 1]?.id
}

const LOAD_MORE_MAX_RETRIES = 4
const LOAD_MORE_RETRY_BASE_MS = 2_000
const LOAD_MORE_RETRY_CAP_MS = 30_000
const MIN_REFETCH_INTERVAL_MS = 15_000

function isNonRetryableError(message: string): boolean {
  const lower = message.toLowerCase()
  return lower.includes('authentication') || lower.includes('unauthorized') || lower.includes('forbidden')
    || lower.includes('no such') || lower.includes('not found')
}

type TimelineItem = {
  type_: TimelineType
  nameKey: string
  category: 'standard' | 'antenna' | 'list' | 'channel' | 'feed'
  customName?: string
  reactionFiltered?: boolean
}

const standardTimelines: TimelineItem[] = [
  { type_: 'home', nameKey: 'timeline.home', category: 'standard' },
  { type_: 'local', nameKey: 'timeline.local', category: 'standard' },
  { type_: 'global', nameKey: 'timeline.global', category: 'standard' },
  { type_: 'hybrid', nameKey: 'timeline.hybrid', category: 'standard' },
  { type_: 'local', nameKey: 'timeline.filtered', category: 'standard', reactionFiltered: true },
]

function getTimelineName(type_: TimelineType): string {
  if (typeof type_ === 'string') {
    switch (type_) {
      case 'home': return t('timeline.home')
      case 'local': return t('timeline.local')
      case 'global': return t('timeline.global')
      case 'hybrid': return t('timeline.hybrid')
      default: return type_
    }
  }
  switch (type_.kind) {
    case 'antenna': return t('timeline.antenna')
    case 'list': return t('timeline.list')
    case 'channel': return t('timeline.channel')
    case 'feed': return t('timeline.feed')
    default: return ''
  }
}

function getTimelineStorageKey(type_: TimelineType): string {
  if (typeof type_ === 'string') return type_
  return `${type_.kind}-${type_.id}`
}

function getItemDisplayName(item: TimelineItem): string {
  return item.customName ?? t(item.nameKey)
}

type TimelineSelectorHookResult = {
  allTimelines: TimelineItem[]
  selectedTimeline: TimelineItem
  selectTimeline: (item: TimelineItem) => void
}

// Extract [id, name] from a list object. Misskey lists use {id, name},
// Bluesky lists use {uri, name}. Fall back to the Misskey helper only for
// shapes that don't match either — it knows about ReScript-wrapped values.
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

function useTimelineSelector(): TimelineSelectorHookResult {
  const [allTimelines, setAllTimelines] = useState<TimelineItem[]>(standardTimelines)
  const [selectedTimeline, setSelectedTimeline] = useState<TimelineItem>(standardTimelines[0])

  useSignalEffect(() => {
    const currentClient = client.value
    if (!currentClient) return
    const antennasVal = antennas.value
    const listsVal = lists.value
    const channelsVal = channels.value
    const feedsVal = feeds.value

    const customItems: TimelineItem[] = []
    antennasVal.forEach(a => {
      const pair = CustomTimelines.extractIdAndName(a)
      if (pair) customItems.push({ type_: { kind: 'antenna', id: pair[0] }, nameKey: 'timeline.antenna', customName: pair[1], category: 'antenna' })
    })
    listsVal.forEach(l => {
      const pair = extractListIdAndName(l)
      if (pair) customItems.push({ type_: { kind: 'list', id: pair[0] }, nameKey: 'timeline.list', customName: pair[1], category: 'list' })
    })
    channelsVal.forEach(ch => {
      const pair = CustomTimelines.extractIdAndName(ch)
      if (pair) customItems.push({ type_: { kind: 'channel', id: pair[0] }, nameKey: 'timeline.channel', customName: pair[1], category: 'channel' })
    })
    // Pinned feeds first so the selector matches the order users see in the
    // official Bluesky app; within each group we keep saved-order.
    const pinnedFeedItems: TimelineItem[] = []
    const savedFeedItems: TimelineItem[] = []
    feedsVal.forEach(f => {
      const view = extractFeedItem(f)
      if (!view) return
      const item: TimelineItem = { type_: { kind: 'feed', id: view.uri }, nameKey: 'timeline.feed', customName: view.displayName, category: 'feed' }
      ;(view.pinned ? pinnedFeedItems : savedFeedItems).push(item)
    })
    setAllTimelines([...standardTimelines, ...customItems, ...pinnedFeedItems, ...savedFeedItems])
  })

  return { allTimelines, selectedTimeline, selectTimeline: setSelectedTimeline }
}

type TimelineSelector = {
  allTimelines: TimelineItem[]
  selectedTimeline: TimelineItem
  onSelect: (item: TimelineItem) => void
}

type TimelineProps = {
  timelineType: TimelineType
  name?: string
  selector?: TimelineSelector
  reactionFiltered?: boolean
}

function itemKey(item: TimelineItem): string {
  const base = typeof item.type_ === 'string' ? item.type_ : `${item.type_.kind}-${item.type_.id}`
  return item.reactionFiltered ? `${base}:filtered` : base
}

function TimelineInner({ timelineType, name, selector, reactionFiltered }: TimelineProps) {
  const [state, setState] = useState<TimelineState>({ tag: 'Loading' })
  const stateRef = useRef(state)
  stateRef.current = state
  const timelineTypeRef = useRef(timelineType)
  timelineTypeRef.current = timelineType
  const subscriptionRef = useRef<BackendSubscription | undefined>(undefined)
  // Mirrored as both state and ref: state drives the cooldown-button re-render,
  // ref is for sync reads inside handlers/closures.
  const [lastFetchedAt, setLastFetchedAt] = useState(0)
  const lastFetchedAtRef = useRef<number>(0)
  lastFetchedAtRef.current = lastFetchedAt
  function markFetched(t: number) {
    lastFetchedAtRef.current = t
    setLastFetchedAt(t)
  }
  const sentinelRef = useRef<HTMLElement | null>(null)
  const topSentinelRef = useRef<HTMLElement | null>(null)
  const [pendingNotes, setPendingNotes] = useState<NoteView[]>([])
  const [isScrolledDown, setIsScrolledDown] = useState(false)
  // Accessed from the streaming callback closure, which captures state at
  // creation. A ref lets the callback read the current scroll position
  // without being re-created on every scroll change.
  const isScrolledDownRef = useRef(false)
  isScrolledDownRef.current = isScrolledDown

  // 1Hz tick while the refresh button is on cooldown. Lets the countdown
  // tooltip update in real time without a permanent global timer.
  const [nowTick, setNowTick] = useState(() => Date.now())
  const cooldownRemainingMs = lastFetchedAt > 0
    ? Math.max(0, MIN_REFETCH_INTERVAL_MS - (nowTick - lastFetchedAt))
    : 0
  const cooldownActive = cooldownRemainingMs > 0
  const cooldownRemainingSecs = Math.ceil(cooldownRemainingMs / 1000)
  useEffect(() => {
    if (!cooldownActive) return
    const id = window.setInterval(() => setNowTick(Date.now()), 1000)
    return () => window.clearInterval(id)
  }, [cooldownActive])

  // "You're all caught up" — read last seen note ID
  const storageKey = `kaguya:lastSeenNoteId:${getTimelineStorageKey(timelineType)}`
  const lastSeenNoteIdRef = useRef<string | undefined>(undefined)
  useEffect(() => {
    lastSeenNoteIdRef.current = localStorage.getItem(storageKey) ?? undefined
  }, [storageKey])

  // Save top note ID on unmount and visibility change
  useEffect(() => {
    function saveLastSeen() {
      const curState = stateRef.current
      if (curState.tag === 'Loaded' && curState.notes[0]) {
        localStorage.setItem(storageKey, curState.notes[0].id)
      }
    }
    function handleVisibilityForSave() {
      if (document.visibilityState === 'hidden') saveLastSeen()
    }
    document.addEventListener('visibilitychange', handleVisibilityForSave)
    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityForSave)
      saveLastSeen()
    }
  }, [storageKey])

  // Track scroll position for new-notes pill and auto-flush pending notes.
  // When the user scrolls back to the top we reveal buffered notes — but only
  // outside quiet mode, since the whole point of quiet mode is to gate visibility
  // behind an explicit "show new" tap.
  useEffect(() => {
    const sentinel = topSentinelRef.current
    if (!sentinel) return
    const observer = new IntersectionObserver(entries => {
      const isVisible = entries[0]?.isIntersecting ?? false
      setIsScrolledDown(!isVisible)
      if (isVisible && !isQuietSignal.value) flushPendingNotes()
    }, { threshold: 0 })
    observer.observe(sentinel)
    return () => observer.disconnect()
  }, [state.tag])

  function makeStreamCallback() {
    return (newNote: unknown) => {
      const decoded = decodeNote(newNote)
      if (!decoded) return

      // Fire-and-forget image prefetch — does not block note display
      prefetchNoteImages(decoded)

      // Buffer when the user can't currently see the top of the list
      // (quiet mode or scrolled-down). Otherwise new notes would silently
      // push their reading position down. At the top we prepend inline —
      // that's the expected live-feed behavior.
      const shouldBuffer = isQuietSignal.value || isScrolledDownRef.current

      if (shouldBuffer) {
        setPendingNotes(prev => {
          if (prev.some(n => n.id === decoded.id)) return prev
          return [decoded, ...prev]
        })
        return
      }

      setState(prev => {
        if (prev.tag !== 'Loaded') return prev
        const exists = prev.notes.some(n => n.id === decoded.id)
        if (exists) return prev
        return { ...prev, notes: [decoded, ...prev.notes] }
      })
    }
  }

  function flushPendingNotes() {
    setPendingNotes(prev => {
      if (prev.length === 0) return prev
      setState(s => {
        if (s.tag !== 'Loaded') return s
        const existingIds = new Set(s.notes.map(n => n.id))
        const newNotes = prev.filter(n => !existingIds.has(n.id))
        return { ...s, notes: [...newNotes, ...s.notes] }
      })
      return []
    })
  }

  useEffect(() => {
    const currentClient = client.value
    let cancelled = false

    setState({ tag: 'Loading' })
    setPendingNotes([])

    async function fetchTimeline() {
      if (!currentClient) {
        if (authState.value !== 'LoggingIn') {
          setState({ tag: 'Error', message: t('error.not_connected') })
        }
        return
      }

      markFetched(Date.now())
      const cached = timelineType === 'home' && !reactionFiltered ? homeTimelineInitial.value : undefined
      // Filtered timeline fetches more notes per page to compensate for client-side filtering
      const pageSize = reactionFiltered ? 50 : 20

      const canStream = streamingEnabled.value

      if (cached !== undefined) {
        if (cancelled) return
        const notes = decodeManyFromJson(Array.isArray(cached) ? cached : [])
        const lastPostId = getLastNoteId(notes)
        setState({ tag: 'Loaded', notes, lastPostId, hasMore: notes.length > 0, isLoadingMore: false, isStreaming: false, loadMoreError: false, loadMoreRetries: 0 })

        if (canStream) {
          const sub = Backend.streamTimeline(currentClient,timelineType, makeStreamCallback())
          subscriptionRef.current = sub
          setState(prev => prev.tag === 'Loaded' ? { ...prev, isStreaming: true } : prev)
        }
      } else {
        if (cancelled) return

        // Filtered timeline: hydrate from the persisted snapshot so the user
        // sees their notes immediately on reload while we fetch newer ones.
        const cachedNotes = reactionFiltered ? loadCachedNotes() : []
        if (cachedNotes.length > 0) {
          setState({
            tag: 'Loaded',
            notes: cachedNotes,
            lastPostId: getLastNoteId(cachedNotes),
            hasMore: true,
            isLoadingMore: false,
            isStreaming: false,
            loadMoreError: false,
            loadMoreRetries: 0,
          })
        }

        const sinceId = cachedNotes[0]?.id
        const notesPromise = Backend.fetchTimeline(currentClient,timelineType, pageSize, sinceId)
        if (canStream) {
          const sub = Backend.streamTimeline(currentClient,timelineType, makeStreamCallback())
          subscriptionRef.current = sub
        }

        const result = await notesPromise
        if (cancelled) return

        if (result.ok) {
          const fetched = decodeManyFromJson(Array.isArray(result.value) ? result.value : [])
          if (sinceId && cachedNotes.length > 0) {
            // since-fetch: prepend only notes we don't already have.
            const existingIds = new Set(cachedNotes.map(n => n.id))
            const newOnes = fetched.filter(n => !existingIds.has(n.id))
            const merged = [...newOnes, ...cachedNotes]
            setState({ tag: 'Loaded', notes: merged, lastPostId: getLastNoteId(merged), hasMore: true, isLoadingMore: false, isStreaming: canStream, loadMoreError: false, loadMoreRetries: 0 })
          } else {
            setState({ tag: 'Loaded', notes: fetched, lastPostId: getLastNoteId(fetched), hasMore: fetched.length > 0, isLoadingMore: false, isStreaming: canStream, loadMoreError: false, loadMoreRetries: 0 })
          }
        } else if (cachedNotes.length === 0) {
          if (subscriptionRef.current) Backend.unsubscribe(subscriptionRef.current)
          subscriptionRef.current = undefined
          setState({ tag: 'Error', message: result.error })
        }
        // else: fetch failed but cached notes are already on screen — leave them.
      }
    }

    void fetchTimeline()

    return () => {
      cancelled = true
      if (subscriptionRef.current) Backend.unsubscribe(subscriptionRef.current)
      subscriptionRef.current = undefined
    }
  }, [client.value, timelineType, reactionFiltered])

  // Persist filtered-timeline notes so a reload doesn't lose them.
  useEffect(() => {
    if (!reactionFiltered) return
    if (state.tag !== 'Loaded') return
    saveCachedNotes(state.notes)
  }, [state, reactionFiltered])

  useEffect(() => {
    const handleVisibility = () => {
      if (document.visibilityState !== 'visible') return
      if (!streamingEnabled.value) return
      const currentClient = client.value
      const curState = stateRef.current
      if (!currentClient || curState.tag !== 'Loaded') return

      const now = Date.now()
      if (now - lastFetchedAtRef.current < MIN_REFETCH_INTERVAL_MS) return
      markFetched(now)

      const newestId = curState.notes[0]?.id
      const tt = timelineTypeRef.current

      if (subscriptionRef.current) Backend.unsubscribe(subscriptionRef.current)
      subscriptionRef.current = Backend.streamTimeline(currentClient,tt, makeStreamCallback())
      setState(prev => prev.tag === 'Loaded' ? { ...prev, isStreaming: true } : prev)

      void (async () => {
        const result = await Backend.fetchTimeline(currentClient,tt, 20, newestId)
        if (result.ok) {
          const newNotes = decodeManyFromJson(Array.isArray(result.value) ? result.value : [])
          if (newNotes.length > 0) {
            setState(prev => prev.tag === 'Loaded' ? { ...prev, notes: [...newNotes, ...prev.notes] } : prev)
          }
        }
      })()
    }

    document.addEventListener('visibilitychange', handleVisibility)
    return () => document.removeEventListener('visibilitychange', handleVisibility)
  }, [])

  async function handleRefresh() {
    if (state.tag === 'Loading') return
    const now = Date.now()
    // Defensive: the UI grays out the button during cooldown, but programmatic
    // callers (e.g. retry buttons) go through here too.
    if (now - lastFetchedAtRef.current < MIN_REFETCH_INTERVAL_MS) return
    markFetched(now)
    const wasStreaming = !!subscriptionRef.current
    setState({ tag: 'Loading' })
    setPendingNotes([])
    const currentClient = client.value
    if (!currentClient) { setState({ tag: 'Error', message: t('error.not_connected') }); return }

    const refreshPageSize = reactionFiltered ? 50 : 20
    const result = await Backend.fetchTimeline(currentClient,timelineType, refreshPageSize)
    if (result.ok) {
      const notes = decodeManyFromJson(Array.isArray(result.value) ? result.value : [])
      setState({ tag: 'Loaded', notes, lastPostId: getLastNoteId(notes), hasMore: notes.length > 0, isLoadingMore: false, isStreaming: wasStreaming, loadMoreError: false, loadMoreRetries: 0 })
    } else {
      setState({ tag: 'Error', message: result.error })
    }
  }

  async function loadMore(force = false) {
    const curState = state
    if (curState.tag !== 'Loaded' || curState.isLoadingMore || !curState.lastPostId) return
    // `force` lets the "retry" button past a stale hasMore:false — useful when
    // rate limits made the last fetch look like end-of-timeline.
    if (!force && !curState.hasMore) return

    setState(prev => prev.tag === 'Loaded' ? { ...prev, isLoadingMore: true, loadMoreError: false } : prev)

    const currentClient = client.value
    if (!currentClient) { setState(prev => prev.tag === 'Loaded' ? { ...prev, isLoadingMore: false } : prev); return }

    const loadMorePageSize = reactionFiltered ? 50 : 20
    const result = await Backend.fetchTimeline(currentClient,timelineType, loadMorePageSize, undefined, curState.lastPostId)
    if (result.ok) {
      const newNotes = decodeManyFromJson(Array.isArray(result.value) ? result.value : [])
      setState(prev => {
        if (prev.tag !== 'Loaded') return prev
        const newLastPostId = getLastNoteId(newNotes)
        return {
          ...prev,
          notes: [...prev.notes, ...newNotes],
          lastPostId: newLastPostId ?? prev.lastPostId,
          hasMore: newNotes.length > 0,
          isLoadingMore: false,
          loadMoreError: false,
          loadMoreRetries: 0,
        }
      })
    } else {
      const errorMsg = result.error
      if (isNonRetryableError(errorMsg)) {
        setState(prev => prev.tag === 'Loaded' ? { ...prev, isLoadingMore: false, loadMoreError: true, loadMoreRetries: LOAD_MORE_MAX_RETRIES } : prev)
      } else {
        setState(prev => {
          if (prev.tag !== 'Loaded') return prev
          const retries = prev.loadMoreRetries + 1
          return { ...prev, isLoadingMore: false, loadMoreError: retries >= LOAD_MORE_MAX_RETRIES, loadMoreRetries: retries }
        })
      }
    }
  }

  useEffect(() => {
    if (state.tag === 'Loaded' && state.loadMoreError) return
    if (state.tag === 'Loaded' && state.loadMoreRetries > 0 && !state.isLoadingMore) {
      // Exponential backoff: 2s, 4s, 8s, 16s — capped at 30s. Gives transient
      // failures (rate limits, brief network blips) time to clear instead of
      // hammering the server.
      const delay = Math.min(
        LOAD_MORE_RETRY_BASE_MS * Math.pow(2, state.loadMoreRetries - 1),
        LOAD_MORE_RETRY_CAP_MS,
      )
      const timer = setTimeout(() => void loadMore(), delay)
      return () => clearTimeout(timer)
    }
    const sentinel = sentinelRef.current
    if (!sentinel) return
    const observer = new IntersectionObserver(entries => {
      if (entries[0]?.isIntersecting) void loadMore()
    }, { threshold: 0.1 })
    observer.observe(sentinel)
    return () => observer.disconnect()
  }, [state])

  const displayName = name || getTimelineName(timelineType)
  const isQuiet = isQuietSignal.value
  const lastSeenId = lastSeenNoteIdRef.current
  // Explicit top-level reads force a re-render when filter state changes.
  // `shouldShowNote` and `passesFilter` read these signals internally, but
  // depending on them here guarantees tracking — no surprises from helper-fn
  // call-stack subtleties.
  const _userFilters = userFilters.value
  void _userFilters
  const activeFilterRules = reactionFiltered ? filterConfig.value.rules : []
  const hasFilterRules = activeFilterRules.length > 0
  const currentHideNsfw = hideNsfw.value

  // Single pass — use this instead of re-filtering in JSX so the empty-state
  // check and the rendered list agree.
  const visibleNotes = state.tag === 'Loaded'
    ? state.notes.filter(shouldShowNote).filter(note => !reactionFiltered || passesFilter(note)).filter(note => !currentHideNsfw || !isNsfw(note))
    : []

  // Count pending notes that would actually appear under the current filter
  // — otherwise the quiet-mode banner lies about how many are waiting.
  const pendingVisibleCount = reactionFiltered
    ? pendingNotes.reduce((n, note) => n + (passesFilter(note) ? 1 : 0), 0)
    : pendingNotes.length

  function revealPendingAndScrollTop() {
    flushPendingNotes()
    topSentinelRef.current?.scrollIntoView({ behavior: 'smooth' })
  }

  return (
    <div class="timeline">
      <div class="timeline-header">
        <div class="timeline-header-left">
          {selector ? (
            <select
              class="timeline-header-select"
              value={itemKey(selector.selectedTimeline)}
              onChange={e => {
                const key = (e.currentTarget as HTMLSelectElement).value
                const next = selector.allTimelines.find(i => itemKey(i) === key)
                if (next) selector.onSelect(next)
              }}
            >
              {(['standard', 'antenna', 'list', 'channel', 'feed'] as const).map(cat => {
                const items = selector.allTimelines.filter(i => i.category === cat)
                if (items.length === 0) return null
                if (cat === 'standard') {
                  return items.map(i => (
                    <option key={itemKey(i)} value={itemKey(i)}>{getItemDisplayName(i)}</option>
                  ))
                }
                return (
                  <optgroup key={cat} label={t(`timeline.${cat}`)}>
                    {items.map(i => (
                      <option key={itemKey(i)} value={itemKey(i)}>{getItemDisplayName(i)}</option>
                    ))}
                  </optgroup>
                )
              })}
            </select>
          ) : (
            <h2>{displayName}</h2>
          )}
          {state.tag === 'Loading' && (
            <span class="timeline-loading-indicator">
              <iconify-icon icon="tabler:loader-2" />
              {t('timeline.loading')}
            </span>
          )}
          {state.tag === 'Loaded' && state.isStreaming && !isQuiet && (
            <span class="streaming-indicator" title={t('timeline.streaming')} aria-label={t('timeline.streaming')}>
              <span class="streaming-dot" />
            </span>
          )}
          {state.tag === 'Loaded' && isQuiet && (
            <span class="quiet-mode-indicator" title={t('quiet_mode.on')}>
              <iconify-icon icon="tabler:player-pause" />
              {t('quiet_mode.status')}
            </span>
          )}
          {reactionFiltered && (
            <span class="filter-indicator" title={t('timeline.filtered_active')}>
              <iconify-icon icon="tabler:filter" />
              {t('timeline.filtered_active')}
            </span>
          )}
        </div>
        <button
          class="secondary outline"
          disabled={cooldownActive || state.tag === 'Loading'}
          title={cooldownActive ? t('action.refresh_cooldown').replace('{s}', String(cooldownRemainingSecs)) : undefined}
          onClick={() => void handleRefresh()}
        >{t('action.refresh')}</button>
      </div>

      {/* Quiet mode: pending notes banner */}
      {isQuiet && pendingVisibleCount > 0 && (
        <div class="quiet-mode-banner">
          <span>{pendingVisibleCount}{t('timeline.new_notes')}</span>
          <button type="button" onClick={flushPendingNotes}>{t('timeline.show_new')}</button>
        </div>
      )}

      {state.tag === 'Error' && (
        <div class="timeline-error-friendly">
          <p>{t('timeline.load_failed')}</p>
          <button
            disabled={cooldownActive}
            title={cooldownActive ? t('action.refresh_cooldown').replace('{s}', String(cooldownRemainingSecs)) : undefined}
            onClick={() => void handleRefresh()}
          >{t('action.retry')}</button>
          <details>
            <summary>{t('timeline.what_went_wrong')}</summary>
            <p>{state.message}</p>
          </details>
        </div>
      )}

      {state.tag === 'Loading' && <TimelineLoadingSkeleton />}

      {state.tag === 'Loaded' && (
        state.notes.length === 0 ? (
          <div class="timeline-empty"><p>{t('timeline.no_notes')}</p></div>
        ) : (
          <>
            {/* Top sentinel for scroll detection */}
            <div ref={el => { topSentinelRef.current = el as HTMLElement | null }} class="top-sentinel" />

            {/* New notes pill: reveals buffered notes and jumps to top. */}
            {!isQuiet && isScrolledDown && pendingVisibleCount > 0 && (
              <div class="new-notes-pill">
                <button type="button" onClick={revealPendingAndScrollTop}>
                  {pendingVisibleCount}{t('timeline.new_notes')}
                </button>
              </div>
            )}

            {/* Filter timeline: guidance when no rules have been set. */}
            {reactionFiltered && !hasFilterRules && (
              <div class="timeline-filter-hint">
                <p>{t('timeline.filter_no_rules')}</p>
                <small>{t('timeline.filter_no_rules_hint')}</small>
              </div>
            )}

            {/* All fetched notes filtered out. Distinct from raw-empty. */}
            {visibleNotes.length === 0 && (
              <div class="timeline-empty">
                <p>
                  {reactionFiltered && hasFilterRules
                    ? t('timeline.filter_hides_all')
                    : reactionFiltered
                      ? t('timeline.filter_no_rules_hint')
                      : t('timeline.user_filter_hides_all')}
                </p>
                {state.hasMore && !state.isLoadingMore && (
                  <button class="secondary outline" type="button" onClick={() => void loadMore()}>
                    {t('action.load_more')}
                  </button>
                )}
              </div>
            )}

            <div class="timeline-notes">
              {visibleNotes.map((note, index) => {
                const showDivider = lastSeenId && note.id === lastSeenId && index > 0
                return (
                  <Fragment key={note.id}>
                    {showDivider && <div class="caught-up-divider">{t('timeline.caught_up')}</div>}
                    <NoteViewComponent note={note} />
                  </Fragment>
                )
              })}
            </div>
            {state.loadMoreError ? (
              <div class="timeline-error-friendly timeline-error-friendly--compact">
                <p>{t('timeline.load_failed_retry')}</p>
                <button class="secondary outline" onClick={() => {
                  setState(prev => prev.tag === 'Loaded' ? { ...prev, loadMoreError: false, loadMoreRetries: 0 } : prev)
                }}>{t('action.retry')}</button>
              </div>
            ) : state.hasMore ? (
              <>
                <div ref={el => { sentinelRef.current = el as HTMLElement | null }} class="timeline-sentinel" />
                {state.isLoadingMore && <div class="timeline-loading-more"><p>{t('timeline.loading')}</p></div>}
              </>
            ) : (
              <div class="timeline-end">
                <p>{t('timeline.no_more')}</p>
                {/* Rate limits can return a short/empty response that looks
                    like end-of-timeline. Let the user force another fetch from
                    the same cursor — if there really is more, it appears. */}
                <button
                  class="secondary outline mt-2"
                  type="button"
                  disabled={state.isLoadingMore}
                  onClick={() => void loadMore(true)}
                >
                  {state.isLoadingMore ? t('timeline.loading') : t('action.retry')}
                </button>
              </div>
            )}
          </>
        )
      )}
    </div>
  )
}

function TimelineLoadingSkeleton() {
  return (
    <div class="timeline-skeleton" aria-hidden="true">
      {Array.from({ length: 5 }, (_, i) => (
        <div class="skeleton-note" key={i}>
          <div class="skeleton-avatar" />
          <div class="skeleton-content">
            <div class="skeleton-line skeleton-line-name" />
            <div class="skeleton-line skeleton-line-long" />
            <div class="skeleton-line skeleton-line-medium" />
          </div>
        </div>
      ))}
    </div>
  )
}

export function Timeline({ timelineType, name }: TimelineProps) {
  return <TimelineInner timelineType={timelineType} name={name} />
}

export function HomePageTimeline() {
  const { allTimelines, selectedTimeline, selectTimeline } = useTimelineSelector()

  return (
    <TimelineInner
      timelineType={selectedTimeline.type_}
      name={getItemDisplayName(selectedTimeline)}
      selector={{ allTimelines, selectedTimeline, onSelect: selectTimeline }}
      reactionFiltered={selectedTimeline.reactionFiltered}
    />
  )
}
