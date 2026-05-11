// SPDX-License-Identifier: MPL-2.0

import type { Emoji, EmojiMap } from './emojiTypes'
import type { CustomEmoji } from '../../lib/misskey'
import * as storage from '../../infra/storage'

const storageKeyEmojis = 'kaguya:emojis:data'
const storageKeyMetadata = 'kaguya:emojis:metadata'
const cacheTTL = 1000 * 60 * 60 * 24 // 24 hours

export function isCacheValid(instanceOrigin: string): boolean {
  try {
    const metaStr = storage.get(storageKeyMetadata)
    if (!metaStr) return false
    const meta = JSON.parse(metaStr)
    const { timestamp, instanceOrigin: cachedOrigin } = meta
    return cachedOrigin === instanceOrigin && Date.now() - timestamp < cacheTTL
  } catch {
    return false
  }
}

export function loadFromCache(host: string): EmojiMap | undefined {
  try {
    const str = storage.get(storageKeyEmojis)
    if (!str) return undefined
    const arr = JSON.parse(str)
    if (!Array.isArray(arr)) return undefined
    const map: EmojiMap = {}
    for (const item of arr) {
      const { name: rawName, url, category, aliases = [] } = item
      if (rawName && url) {
        const name = host && rawName.endsWith('@.') ? rawName.slice(0, -2) + '@' + host : rawName
        const emoji: Emoji = { name, url, category, aliases }
        map[name] = emoji
        for (const alias of aliases) {
          if (alias) {
            const normAlias = host && alias.endsWith('@.') ? alias.slice(0, -2) + '@' + host : alias
            map[normAlias] = emoji
          }
        }
      }
    }
    return map
  } catch {
    return undefined
  }
}

export function saveToCache(emojiList: CustomEmoji[], instanceOrigin: string): void {
  try {
    storage.set(storageKeyEmojis, JSON.stringify(emojiList.map(e => ({
      name: e.name,
      url: e.url,
      category: e.category ?? null,
      aliases: e.aliases,
    }))))
    storage.set(storageKeyMetadata, JSON.stringify({ timestamp: Date.now(), instanceOrigin }))
  } catch {
    // ignore
  }
}

export function clearCache(): void {
  storage.remove(storageKeyEmojis)
  storage.remove(storageKeyMetadata)
}
