// SPDX-License-Identifier: MPL-2.0
//
// Shared emoji rendering components and text helpers.
// Extracted from MfmRenderer.tsx for reuse by the unified SocialRenderer.

import { useEffect, useRef } from 'preact/hooks'
import { getEmoji, lazyLoadGlobal } from '../../domain/emoji/emojiStore'
import { client } from '../../domain/auth/appState'
import { proxyUrl } from '../../infra/mediaProxy'
import { observeImage, unobserveImage, isLoaded as isImageLoaded } from '../../infra/fetchQueue'
import type { FetchPriority } from '../../infra/fetchQueue'
import twemoji from 'twemoji'

export type { FetchPriority } from '../../infra/fetchQueue'

const TWEMOJI_BASE = '/twemoji'

export function toTwemojiUrl(emoji: string): string {
  const stripped = emoji.includes('\u200d') ? emoji : emoji.replace(/\ufe0f/g, '')
  return `${TWEMOJI_BASE}/${twemoji.convert.toCodePoint(stripped)}.svg`
}

export function EmojiImg({ url, name, priority }: { url: string; name: string; priority: FetchPriority }) {
  const ref = useRef<HTMLImageElement>(null)
  const proxied = proxyUrl(url)

  useEffect(() => {
    const el = ref.current
    if (!el) return
    if (isImageLoaded(proxied)) {
      el.src = proxied
    } else {
      observeImage(el, proxied, priority)
    }
    return () => { if (el) unobserveImage(el) }
  }, [proxied, priority])

  return (
    <img
      ref={ref}
      class="mfm-emoji-image"
      alt={`:${name}:`}
      title={`:${name}:`}
    />
  )
}

export function EmojiCode({ name, priority }: { name: string; priority: FetchPriority }) {
  const emoji = getEmoji(name)
  if (emoji) {
    return <EmojiImg url={proxyUrl(emoji.url)} name={name} priority={priority} />
  }
  const currentClient = client.value
  if (currentClient && currentClient.backend === 'misskey') void lazyLoadGlobal(currentClient.client)
  return <span class="mfm-emoji-code">:{name}:</span>
}

export function hasJapanese(text: string): boolean {
  return /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF\u3400-\u4DBF]/.test(text)
}

export function hasKorean(text: string): boolean {
  return /[\uAC00-\uD7AF\u1100-\u11FF]/.test(text)
}
