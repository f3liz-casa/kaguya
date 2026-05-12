// SPDX-License-Identifier: MPL-2.0
//
// Framework-agnostic helpers extracted from emojiComponents.tsx so the
// Svelte renderer can share the same twemoji URL builder and CJK-line-
// break detection as the Preact tree.

import twemoji from 'twemoji'

export type { FetchPriority } from '../../infra/fetchQueue'

const TWEMOJI_BASE = '/twemoji'

export function toTwemojiUrl(emoji: string): string {
  const stripped = emoji.includes('‍') ? emoji : emoji.replace(/️/g, '')
  return `${TWEMOJI_BASE}/${twemoji.convert.toCodePoint(stripped)}.svg`
}

export function hasJapanese(text: string): boolean {
  return /[぀-ゟ゠-ヿ一-龯㐀-䶿]/.test(text)
}

export function hasKorean(text: string): boolean {
  return /[가-힯ᄀ-ᇿ]/.test(text)
}
