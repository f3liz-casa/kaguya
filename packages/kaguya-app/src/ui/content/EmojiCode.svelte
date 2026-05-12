<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of EmojiCode from emojiComponents.tsx. Resolves a custom
  emoji name through the local emoji store; if registered, renders via
  EmojiImg, otherwise falls back to a `:name:` span and triggers the
  misskey global emoji bulk-load.
-->

<script lang="ts">
  import { getEmoji, lazyLoadGlobal } from '../../domain/emoji/emojiStore'
  import { client } from '../../domain/auth/appState'
  import { proxyUrl } from '../../infra/mediaProxy'
  import type { FetchPriority } from '../../infra/fetchQueue'
  import EmojiImg from './EmojiImg.svelte'

  type Props = { name: string; priority: FetchPriority }
  let { name, priority }: Props = $props()

  const emoji = $derived(getEmoji(name))

  $effect(() => {
    if (emoji) return
    const currentClient = client.peek()
    if (currentClient && currentClient.backend === 'misskey') void lazyLoadGlobal(currentClient.client)
  })
</script>

{#if emoji}
  <EmojiImg url={proxyUrl(emoji.url)} {name} {priority} />
{:else}
  <span class="mfm-emoji-code" aria-label={`${name} emoji`}><span aria-hidden="true">:{name}:</span></span>
{/if}
