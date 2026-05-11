// SPDX-License-Identifier: MPL-2.0

import { useState, useEffect, useRef } from 'preact/hooks'
import { Layout } from '../ui/Layout'
import * as Backend from '../lib/backend'
import { CustomTimelines } from '../lib/misskey'
import { client, instanceName } from '../domain/auth/appState'
import { decodeManyFromJson } from '../domain/note/noteDecoder'
import type { NoteView } from '../domain/note/noteView'
import type { TimelineType } from '../lib/backend'
import { antennas, lists, channels } from '../domain/timeline/timelineStore'
import { NoteViewComponent } from '../domain/note/Note'
import { shouldShowNote, userFilters } from '../domain/user/userFilterStore'
import { t } from '../infra/i18n'

const LAST_SEEN_PREFIX = 'kaguya:lastSeenNoteId:'
const SHOWN_AT_PREFIX = 'kaguya:timelineInboxShownAt:'
const ONE_DAY_MS = 86400000

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

type TimelineSource = {
  storageKey: string
  type_: TimelineType
  name: string
  notes: NoteView[]
  hasMore: boolean
}

type SourceSectionProps = {
  source: TimelineSource
  onMarkRead: (source: TimelineSource) => void
}

function SourceSection({ source, onMarkRead }: SourceSectionProps) {
  const sectionRef = useRef<HTMLElement | null>(null)

  // Record shownAt when section enters viewport
  useEffect(() => {
    const el = sectionRef.current
    if (!el) return
    const shownAtKey = SHOWN_AT_PREFIX + source.storageKey
    const observer = new IntersectionObserver(entries => {
      if (entries[0]?.isIntersecting) {
        if (!localStorage.getItem(shownAtKey)) {
          localStorage.setItem(shownAtKey, String(Date.now()))
        }
        observer.disconnect()
      }
    }, { threshold: 0.1 })
    observer.observe(el)
    return () => observer.disconnect()
  }, [source.storageKey])

  const count = source.hasMore ? '30+' : String(source.notes.length)
  // Explicit subscription so toggling user filters updates the rendered list.
  const _userFilters = userFilters.value
  void _userFilters

  return (
    <section ref={el => { sectionRef.current = el as HTMLElement | null }} class="timeline-inbox-source">
      <div class="timeline-inbox-source-header">
        <iconify-icon icon={timelineIcon(source.type_)} class="timeline-inbox-source-icon" />
        <span class="timeline-inbox-source-name">{source.name}</span>
        <span class="inbox-group-count">{count}</span>
        <button
          class="timeline-inbox-mark-read-btn"
          type="button"
          title={t('inbox.mark_read')}
          aria-label={t('inbox.mark_read')}
          onClick={() => onMarkRead(source)}
        >
          <iconify-icon icon="tabler:check" />
        </button>
      </div>
      <div class="timeline-notes">
        {source.notes.filter(shouldShowNote).map(note => (
          <NoteViewComponent key={note.id} note={note} noteHost={instanceName.value} />
        ))}
      </div>
    </section>
  )
}

export function TimelineInboxPage() {
  const [sources, setSources] = useState<TimelineSource[]>([])
  const [loaded, setLoaded] = useState(false)

  useEffect(() => {
    const currentClient = client.value
    if (!currentClient) { setLoaded(true); return }

    const now = Date.now()

    // Build candidate list from known standard + custom timelines
    const candidates: Array<{ storageKey: string; type_: TimelineType; name: string }> = [
      { storageKey: 'home',   type_: 'home',   name: t('timeline.home') },
      { storageKey: 'local',  type_: 'local',  name: t('timeline.local') },
      { storageKey: 'global', type_: 'global', name: t('timeline.global') },
      { storageKey: 'hybrid', type_: 'hybrid', name: t('timeline.hybrid') },
    ]

    for (const a of antennas.value) {
      const pair = CustomTimelines.extractIdAndName(a)
      if (pair) candidates.push({ storageKey: `antenna-${pair[0]}`, type_: { kind: 'antenna', id: pair[0] }, name: pair[1] })
    }
    for (const l of lists.value) {
      const pair = CustomTimelines.extractIdAndName(l)
      if (pair) candidates.push({ storageKey: `list-${pair[0]}`, type_: { kind: 'list', id: pair[0] }, name: pair[1] })
    }
    for (const ch of channels.value) {
      const pair = CustomTimelines.extractIdAndName(ch)
      if (pair) candidates.push({ storageKey: `channel-${pair[0]}`, type_: { kind: 'channel', id: pair[0] }, name: pair[1] })
    }

    // Resolve "shown 1 day ago" cleanup before fetching
    for (const c of candidates) {
      const shownAtRaw = localStorage.getItem(SHOWN_AT_PREFIX + c.storageKey)
      if (shownAtRaw) {
        const shownAt = parseInt(shownAtRaw, 10)
        if (now - shownAt >= ONE_DAY_MS) {
          // Source was shown to user 1+ day ago — it will be excluded below
          // since we'll treat it as having no new notes by advancing lastSeenId
          // (we fetch and then silently advance without displaying)
          localStorage.removeItem(SHOWN_AT_PREFIX + c.storageKey)
        }
      }
    }

    // Keep only sources that have a saved lastSeenId (i.e. user visited them)
    const tracked = candidates.filter(c => localStorage.getItem(LAST_SEEN_PREFIX + c.storageKey) !== null)

    // Exclude sources that were shown >1 day ago (already cleaned up above via removeItem,
    // but we also need to advance their lastSeenId so they don't reappear)
    // Actually: after removing shownAt, if still tracked, they'll fetch new notes again.
    // The 1-day cleanup should advance lastSeenId to "now" by fetching and marking read.
    // Let's split into "to display" vs "to auto-advance".
    const toDisplay: typeof tracked = []
    const toAutoAdvance: typeof tracked = []

    for (const c of candidates) {
      const hasLastSeen = localStorage.getItem(LAST_SEEN_PREFIX + c.storageKey) !== null
      if (!hasLastSeen) continue
      const shownAtRaw = localStorage.getItem(SHOWN_AT_PREFIX + c.storageKey)
      const wasShownLongAgo = shownAtRaw
        ? now - parseInt(shownAtRaw, 10) >= ONE_DAY_MS
        : false
      if (wasShownLongAgo) {
        toAutoAdvance.push(c)
      } else {
        toDisplay.push(c)
      }
    }

    void (async () => {
      // Auto-advance sources that were shown 1+ day ago (mark as read silently)
      await Promise.all(
        toAutoAdvance.map(async ({ storageKey, type_ }) => {
          const result = await Backend.fetchTimeline(currentClient,type_, 1)
          if (result.ok) {
            const decoded = decodeManyFromJson(Array.isArray(result.value) ? result.value : [])
            const newestId = decoded[0]?.id
            if (newestId) localStorage.setItem(LAST_SEEN_PREFIX + storageKey, newestId)
          }
          localStorage.removeItem(SHOWN_AT_PREFIX + storageKey)
        })
      )

      if (toDisplay.length === 0) { setLoaded(true); return }

      // Fetch new notes for display sources
      const results = await Promise.all(
        toDisplay.map(async ({ storageKey, type_, name }) => {
          const lastSeenId = localStorage.getItem(LAST_SEEN_PREFIX + storageKey)!
          const result = await Backend.fetchTimeline(currentClient,type_, 30, lastSeenId)
          if (!result.ok) return null
          const decoded = decodeManyFromJson(Array.isArray(result.value) ? result.value : [])
          if (decoded.length === 0) return null
          return { storageKey, type_, name, notes: decoded, hasMore: decoded.length >= 30 }
        })
      )
      setSources(results.filter((s): s is TimelineSource => s !== null))
      setLoaded(true)
    })()
  }, [])

  function markRead(source: TimelineSource) {
    const newestId = source.notes[0]?.id
    if (newestId) localStorage.setItem(LAST_SEEN_PREFIX + source.storageKey, newestId)
    localStorage.removeItem(SHOWN_AT_PREFIX + source.storageKey)
    setSources(prev => prev.filter(s => s.storageKey !== source.storageKey))
  }

  return (
    <Layout>
      <div class="timeline-inbox-container">
        <div class="inbox-header">
          <h2 class="inbox-title">{t('timeline_inbox.title')}</h2>
        </div>

        {!loaded && (
          <div class="timeline-loading-more"><p>{t('timeline.loading')}</p></div>
        )}

        {loaded && sources.length === 0 && (
          <div class="inbox-empty">
            <div class="inbox-empty-icon">✨</div>
            <p class="inbox-empty-text">{t('inbox.empty')}</p>
          </div>
        )}

        {sources.map(source => (
          <SourceSection key={source.storageKey} source={source} onMarkRead={markRead} />
        ))}
      </div>
    </Layout>
  )
}
