// SPDX-License-Identifier: MPL-2.0

/**
 * Unified priority image fetch queue.
 *
 * All image loading in the app (emoji, avatars, note files, reactions, cache
 * warming) funnels through this single queue so that high-value resources are
 * never starved by bulk preloads.
 *
 * Priority levels (lower = more urgent):
 *
 *   1 – Note text inline emoji           (viewport-visible MFM content)
 *   2 – User profile images              (avatars in timeline / notifications)
 *   3 – User profile text MFM emoji      (display names, bio emoji)
 *   4 – Note attachment images           (files attached to notes)
 *   5 – Note reaction emoji              (reaction bar per note)
 *   6 – Local instance emoji cache       (background warming, local instance)
 *   7 – Remote / follower emoji cache    (background warming, remote instances)
 *
 * Background priorities (P6/P7) are skipped entirely when the user is on a
 * content page and the network is slow, preserving bandwidth for content.
 *
 * Concurrency is capped at MAX_CONCURRENT. Items are always dispatched
 * highest-priority-first. An inQueue Set gives O(1) duplicate detection so
 * bulk enqueueMany calls on large emoji lists don't become O(n²).
 */

import { avgApiDuration, totalApiCalls } from './perfMonitor'

export type FetchPriority = 1 | 2 | 3 | 4 | 5 | 6 | 7

/** Priorities at or above this threshold are considered background work. */
const BACKGROUND_THRESHOLD: FetchPriority = 6

const SLOW_NETWORK_MS = 500
const MIN_SAMPLES = 3
const MAX_CONCURRENT = 6

// ---------------------------------------------------------------------------
// Network / page helpers
// ---------------------------------------------------------------------------

function isOnContentPage(): boolean {
  const path = globalThis.location?.pathname ?? ''
  return path === '/' || path.startsWith('/notes/') || path === '/inbox'
}

function isNetworkSlow(): boolean {
  return totalApiCalls.peek() >= MIN_SAMPLES && avgApiDuration.peek() > SLOW_NETWORK_MS
}

/** Returns true when background loading (P6/P7) should be deferred. */
export function shouldSkipBackgroundLoading(): boolean {
  return isOnContentPage() && isNetworkSlow()
}

// ---------------------------------------------------------------------------
// Queue state
// ---------------------------------------------------------------------------

type Entry = {
  url: string
  priority: FetchPriority
  callbacks: Array<() => void>
}

const queue: Entry[] = []
const inQueue = new Set<string>()   // O(1) "is this URL already queued?"
const loading = new Set<string>()   // currently fetching
const loaded = new Set<string>()    // completed (success or error)

function resort(): void {
  queue.sort((a, b) => a.priority - b.priority)
}

function processQueue(): void {
  while (loading.size < MAX_CONCURRENT && queue.length > 0) {
    const entry = queue.shift()!
    inQueue.delete(entry.url)

    if (loaded.has(entry.url)) {
      // Already done (e.g. loaded while sitting in queue)
      for (const cb of entry.callbacks) cb()
      continue
    }

    loading.add(entry.url)
    const img = new Image()
    const done = () => {
      loading.delete(entry.url)
      loaded.add(entry.url)
      for (const cb of entry.callbacks) cb()
      processQueue()
    }
    img.onload = done
    img.onerror = done
    img.src = entry.url
  }
}

// ---------------------------------------------------------------------------
// Public API — enqueueing
// ---------------------------------------------------------------------------

/**
 * Enqueue an image URL at the given priority.
 * Returns a Promise that resolves once the image has loaded (or errored).
 * If the URL is already loaded or in-flight, resolves immediately.
 */
export function enqueue(url: string, priority: FetchPriority): Promise<void> {
  if (loaded.has(url) || loading.has(url)) return Promise.resolve()

  return new Promise<void>(resolve => {
    if (inQueue.has(url)) {
      const existing = queue.find(e => e.url === url)!
      if (priority < existing.priority) {
        existing.priority = priority
        resort()
      }
      existing.callbacks.push(resolve)
    } else {
      queue.push({ url, priority, callbacks: [resolve] })
      inQueue.add(url)
      resort()
    }
    processQueue()
  })
}

/**
 * Boost an already-queued URL to a higher (lower-numbered) priority.
 * No-op if the URL is not in the queue or already at/above the given priority.
 */
export function boostPriority(url: string, priority: FetchPriority): void {
  if (!inQueue.has(url)) return
  const entry = queue.find(e => e.url === url)
  if (entry && priority < entry.priority) {
    entry.priority = priority
    resort()
  }
}

/** Returns true if the URL has already been loaded through this queue. */
export function isLoaded(url: string): boolean {
  return loaded.has(url)
}

/**
 * Batch-enqueue many URLs at the same priority.
 * Skips background priorities (P6/P7) when network is slow on a content page.
 * Already-loaded and already-queued URLs are silently skipped (O(1) per URL).
 */
export function enqueueMany(urls: string[], priority: FetchPriority): void {
  if (priority >= BACKGROUND_THRESHOLD && shouldSkipBackgroundLoading()) return

  let added = false
  for (const url of urls) {
    if (loaded.has(url) || inQueue.has(url) || loading.has(url)) continue
    queue.push({ url, priority, callbacks: [] })
    inQueue.add(url)
    added = true
  }
  if (added) {
    resort()
    processQueue()
  }
}

// ---------------------------------------------------------------------------
// Viewport-aware loading via IntersectionObserver
// ---------------------------------------------------------------------------

type Observed = { el: HTMLImageElement; url: string }
const observed = new Map<HTMLImageElement, Observed>()
let intersectionObserver: IntersectionObserver | undefined

function getObserver(): IntersectionObserver {
  if (!intersectionObserver) {
    intersectionObserver = new IntersectionObserver(
      entries => {
        for (const e of entries) {
          if (!e.isIntersecting) continue
          const el = e.target as HTMLImageElement
          const tracked = observed.get(el)
          if (!tracked) continue
          // Boost to P1 (note text inline) when entering viewport
          boostPriority(tracked.url, 1)
          void enqueue(tracked.url, 1).then(() => {
            if (el.dataset.queueSrc === tracked.url) {
              el.src = tracked.url
              delete el.dataset.queueSrc
            }
          })
          intersectionObserver!.unobserve(el)
          observed.delete(el)
        }
      },
      { rootMargin: '200px' },
    )
  }
  return intersectionObserver
}

/**
 * Register an <img> element for priority-queue loading with automatic
 * viewport boosting.
 *
 * - If the URL is already loaded: sets `src` immediately.
 * - Otherwise: enqueues at `priority`, sets src when loaded, and observes
 *   for viewport entry (200 px margin) to boost priority to P1.
 */
export function observeImage(
  el: HTMLImageElement,
  url: string,
  priority: FetchPriority,
): void {
  if (loaded.has(url)) {
    el.src = url
    return
  }
  el.dataset.queueSrc = url
  void enqueue(url, priority).then(() => {
    if (el.dataset.queueSrc === url) {
      el.src = url
      delete el.dataset.queueSrc
    }
  })
  observed.set(el, { el, url })
  getObserver().observe(el)
}

/** Unregister an element — call on component unmount. */
export function unobserveImage(el: HTMLImageElement): void {
  intersectionObserver?.unobserve(el)
  observed.delete(el)
}
