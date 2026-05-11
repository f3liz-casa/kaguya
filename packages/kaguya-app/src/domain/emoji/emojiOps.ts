// SPDX-License-Identifier: MPL-2.0

import { addEmojis, getEmojiUrl as storeGetEmojiUrl } from './emojiStore'
import { asObj } from '../../infra/jsonUtils'

export function extractFromJsonDict(emojisDict: Record<string, unknown>): Record<string, string> {
  const result: Record<string, string> = {}
  for (const [name, urlVal] of Object.entries(emojisDict)) {
    if (typeof urlVal === 'string') result[name] = urlVal
  }
  return result
}

/**
 * Extract emoji from array format used by some Misskey versions / forks.
 * Format: [{ name: "emoji_name", url: "https://..." }, ...]
 */
export function extractFromJsonArray(arr: unknown[]): Record<string, string> {
  const result: Record<string, string> = {}
  for (const item of arr) {
    if (item && typeof item === 'object' && !Array.isArray(item)) {
      const obj = item as Record<string, unknown>
      const name = obj['name']
      const url = obj['url']
      if (typeof name === 'string' && typeof url === 'string') {
        result[name] = url
      }
    }
  }
  return result
}

function cacheField(noteObj: Record<string, unknown>, field: string): void {
  const val = noteObj[field]
  // Handle both dict format { name: url } and array format [{ name, url }]
  if (Array.isArray(val)) {
    const dict = extractFromJsonArray(val)
    if (Object.keys(dict).length > 0) addEmojis(dict)
    return
  }
  const fieldObj = asObj(val)
  if (!fieldObj) return
  const dict = extractFromJsonDict(fieldObj)
  if (Object.keys(dict).length > 0) addEmojis(dict)
}

export function extractAndCache(noteObj: Record<string, unknown>): void {
  cacheField(noteObj, 'reactionEmojis')
  cacheField(noteObj, 'emojis')
}

export function getEmojiUrl(reaction: string, reactionEmojis: Record<string, string>): string | undefined {
  const emojiName = reaction.startsWith(':') && reaction.endsWith(':')
    ? reaction.slice(1, reaction.length - 1)
    : reaction

  // Note-level reactionEmojis dict uses original @. keys from API
  if (reactionEmojis[emojiName]) return reactionEmojis[emojiName]

  // For local emojis (@.), strip suffix and let store resolve via host fallback
  if (emojiName.endsWith('@.')) {
    const base = emojiName.slice(0, emojiName.length - 2)
    return storeGetEmojiUrl(base)
  }
  return storeGetEmojiUrl(emojiName)
}

export function isUnicodeEmoji(reaction: string): boolean {
  return !reaction.startsWith(':')
}
