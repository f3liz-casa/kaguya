<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of EmojiImg from emojiComponents.tsx. Lazy-loads via
  observeImage / unobserveImage on the shared fetchQueue.
-->

<script lang="ts">
  import { proxyUrl } from '../../infra/mediaProxy'
  import { observeImage, unobserveImage, isLoaded as isImageLoaded } from '../../infra/fetchQueue'
  import type { FetchPriority } from '../../infra/fetchQueue'

  type Props = { url: string; name: string; priority: FetchPriority }
  let { url, name, priority }: Props = $props()

  const proxied = $derived(proxyUrl(url))
  let imgEl = $state<HTMLImageElement | null>(null)

  $effect(() => {
    const el = imgEl
    if (!el) return
    const target = proxied
    if (isImageLoaded(target)) {
      el.src = target
    } else {
      observeImage(el, target, priority)
    }
    return () => { unobserveImage(el) }
  })
</script>

<img
  bind:this={imgEl}
  class="mfm-emoji-image"
  alt={`:${name}:`}
  title={`:${name}:`}
/>
