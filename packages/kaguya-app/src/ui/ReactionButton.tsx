// SPDX-License-Identifier: MPL-2.0

import { useEffect, useRef } from 'preact/hooks'
import { isUnicodeEmoji, getEmojiUrl } from '../domain/emoji/emojiOps'
import { observeImage, unobserveImage, isLoaded as isImageLoaded } from '../infra/fetchQueue'
import { proxyUrl } from '../infra/mediaProxy'
import { toTwemojiUrl } from './content/emojiComponents'

type Props = {
  reaction: string
  count: number
  reactionEmojis: Record<string, string>
}

function ReactionEmojiImg({ url, alt }: { url: string; alt: string }) {
  const ref = useRef<HTMLImageElement>(null)

  const proxied = proxyUrl(url)

  useEffect(() => {
    const el = ref.current
    if (!el) return
    if (isImageLoaded(proxied)) {
      el.src = proxied
    } else {
      observeImage(el, proxied, 5)
    }
    return () => { if (el) unobserveImage(el) }
  }, [proxied])

  return (
    <img
      ref={ref}
      className="reaction-emoji-img"
      alt={alt}
    />
  )
}

export function ReactionButton({ reaction, count, reactionEmojis }: Props) {
  const emojiUrl = isUnicodeEmoji(reaction) ? undefined : getEmojiUrl(reaction, reactionEmojis)

  return (
    <div
      className="reaction-display"
      role="img"
      aria-label={`${reaction} - ${count} reaction${count === 1 ? '' : 's'}`}
    >
      {emojiUrl
        ? <ReactionEmojiImg url={emojiUrl} alt={reaction} />
        : isUnicodeEmoji(reaction)
          ? <img className="reaction-emoji-img" src={toTwemojiUrl(reaction)} alt={reaction} />
          : <span className="reaction-emoji-code">{reaction}</span>
      }
      <span className="reaction-count">{count}</span>
    </div>
  )
}
