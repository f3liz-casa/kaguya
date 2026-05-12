<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of ReactionButton.tsx. Displays one reaction's emoji
  (custom image / unicode twemoji / fallback span) + count. The
  parent ReactionBar.svelte wraps this in the actual <button>.

  ReactionEmojiImg's lazy-load via observeImage is inlined into this
  component since the trio is small enough that splitting again would
  be noise.
-->

<script lang="ts">
  import { isUnicodeEmoji, getEmojiUrl } from '../domain/emoji/emojiOps'
  import { observeImage, unobserveImage, isLoaded as isImageLoaded } from '../infra/fetchQueue'
  import { proxyUrl } from '../infra/mediaProxy'
  import { toTwemojiUrl } from './content/emojiHelpers'

  type Props = { reaction: string; count: number; reactionEmojis: Record<string, string> }
  let { reaction, count, reactionEmojis }: Props = $props()

  const customUrl = $derived(isUnicodeEmoji(reaction) ? undefined : getEmojiUrl(reaction, reactionEmojis))
  const proxied = $derived(customUrl ? proxyUrl(customUrl) : undefined)

  let imgEl = $state<HTMLImageElement | null>(null)

  $effect(() => {
    const el = imgEl
    if (!el || !proxied) return
    if (isImageLoaded(proxied)) {
      el.src = proxied
    } else {
      observeImage(el, proxied, 5)
    }
    return () => { unobserveImage(el) }
  })
</script>

<div
  class="reaction-display"
  role="img"
  aria-label={`${reaction} - ${count} reaction${count === 1 ? '' : 's'}`}
>
  {#if proxied}
    <img bind:this={imgEl} class="reaction-emoji-img" alt={reaction} />
  {:else if isUnicodeEmoji(reaction)}
    <img class="reaction-emoji-img" src={toTwemojiUrl(reaction)} alt={reaction} />
  {:else}
    <span class="reaction-emoji-code">{reaction}</span>
  {/if}
  <span class="reaction-count">{count}</span>
</div>
