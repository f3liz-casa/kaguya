// SPDX-License-Identifier: MPL-2.0

import { signal } from '@preact/signals'
import { get, set, remove } from '../../infra/storage'
import { keyFilteredTimelineRules, keyFilteredTimelineCache } from '../../infra/storage'
import type { NoteView } from '../note/noteView'
import { isPureRenote } from '../note/noteView'

const CACHED_NOTES_LIMIT = 50

export type RuleOperator = '>' | '<' | '>=' | '<=' | '=='

export type ReactionRule = {
  id: string
  emoji: string
  operator: RuleOperator
  threshold: number
}

export type FilterLogic = 'AND' | 'OR'

export type FilterConfig = {
  rules: ReactionRule[]
  logic: FilterLogic
}

const DEFAULT_CONFIG: FilterConfig = { rules: [], logic: 'AND' }

export const filterConfig = signal<FilterConfig>(DEFAULT_CONFIG)

export function initFilteredTimeline(): void {
  const stored = get(keyFilteredTimelineRules)
  if (!stored) return
  try {
    const parsed = JSON.parse(stored) as FilterConfig
    if (parsed && Array.isArray(parsed.rules)) {
      filterConfig.value = parsed
    }
  } catch { /* ignore malformed data */ }
}

function save(): void {
  set(keyFilteredTimelineRules, JSON.stringify(filterConfig.value))
}

export function addRule(emoji: string, operator: RuleOperator, threshold: number): void {
  const id = String(Date.now())
  filterConfig.value = {
    ...filterConfig.value,
    rules: [...filterConfig.value.rules, { id, emoji: emoji.trim(), operator, threshold }],
  }
  save()
}

export function removeRule(id: string): void {
  filterConfig.value = {
    ...filterConfig.value,
    rules: filterConfig.value.rules.filter(r => r.id !== id),
  }
  save()
}

export function updateRule(id: string, patch: Partial<Omit<ReactionRule, 'id'>>): void {
  filterConfig.value = {
    ...filterConfig.value,
    rules: filterConfig.value.rules.map(r => r.id === id ? { ...r, ...patch } : r),
  }
  save()
}

export function setFilterLogic(logic: FilterLogic): void {
  filterConfig.value = { ...filterConfig.value, logic }
  save()
}

/** Strip Misskey reaction key format to bare name.
 *  ":kawaii@.:"  → "kawaii"
 *  ":smile@misskey.io:" → "smile"
 *  ":tada:"  → "tada"
 *  "😊"      → "😊"
 *  "kawaii"  → "kawaii"  (user-typed bare name passes through)
 */
function reactionKeyName(key: string): string {
  const m = key.trim().match(/^:([^@:]+)(?:@[^:]*)?:$/)
  return m ? m[1].toLowerCase() : key.trim().toLowerCase()
}

function reactionCount(note: NoteView, emojiName: string): number {
  // Normalize *both* sides through reactionKeyName so user input with or
  // without `:` wrappers or `@host` suffixes matches reaction keys consistently.
  // Substring match so e.g. "kawaii" also matches "kawaii2", "kawaii_party".
  const target = reactionKeyName(emojiName)
  if (!target) return 0
  let total = 0
  for (const [key, count] of Object.entries(note.reactions)) {
    if (reactionKeyName(key).includes(target)) total += count
  }
  return total
}

function passesRule(note: NoteView, rule: ReactionRule): boolean {
  const count = reactionCount(note, rule.emoji)
  switch (rule.operator) {
    case '>':  return count >  rule.threshold
    case '<':  return count <  rule.threshold
    case '>=': return count >= rule.threshold
    case '<=': return count <= rule.threshold
    case '==': return count === rule.threshold
  }
}

/** Persisted snapshot of the filtered timeline so a reload doesn't drop the
 *  notes the user already had — the filter is heavy and refetching from a
 *  cold start can leave them staring at an empty list while a new batch
 *  trickles in. */
export function loadCachedNotes(): NoteView[] {
  const stored = get(keyFilteredTimelineCache)
  if (!stored) return []
  try {
    const parsed = JSON.parse(stored)
    return Array.isArray(parsed) ? (parsed as NoteView[]) : []
  } catch {
    return []
  }
}

export function saveCachedNotes(notes: NoteView[]): void {
  try {
    set(keyFilteredTimelineCache, JSON.stringify(notes.slice(0, CACHED_NOTES_LIMIT)))
  } catch {
    // Quota likely — drop the cache rather than leave a half-written value.
    try { remove(keyFilteredTimelineCache) } catch { /* ignore */ }
  }
}

export function passesFilter(note: NoteView): boolean {
  const { rules, logic } = filterConfig.value
  if (rules.length === 0) return true
  // Pure renotes carry no reactions on the wrapper — the reactions the user
  // cares about live on the inner target note. Unwrap once so all rules see
  // the same note.
  const target = isPureRenote(note) && note.renote ? note.renote : note
  return logic === 'AND'
    ? rules.every(r => passesRule(target, r))
    : rules.some(r => passesRule(target, r))
}
