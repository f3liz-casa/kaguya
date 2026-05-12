<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of ContentRenderer.tsx, restricted to the parseSimple
  subset. Surface: { text, parseSimple: true } — full MFM (parse()),
  HTML, Bluesky facets, and emoji image rendering are deferred to M4
  where the PostForm port lands the full pipeline.

  parseSimple nodes are limited to: text / unicodeEmoji / emojiCode /
  mention / hashtag. emojiCode falls back to ":name:" span — identical
  to the Preact implementation's fallback path when the emoji store
  has not yet resolved the URL, so behavior is preserved (no feature
  regression at mount swap).
-->

<script lang="ts">
  import * as mfm from 'mfm-js'

  type Props = { text: string; parseSimple: true }
  let { text }: Props = $props()

  const nodes = $derived(mfm.parseSimple(text))
</script>

<span class="mfm-content">
  {#each nodes as node}
    {#if node.type === 'text'}{node.props.text}
    {:else if node.type === 'unicodeEmoji'}{node.props.emoji}
    {:else if node.type === 'emojiCode'}<span class="mfm-emoji-code">:{node.props.name}:</span>
    {:else if node.type === 'mention'}<a class="mfm-mention" href={`/@${node.props.acct}`}>@{node.props.username}{#if node.props.host}@{node.props.host}{/if}</a>
    {:else if node.type === 'hashtag'}<a class="mfm-hashtag" href={`/tags/${node.props.hashtag}`}>#{node.props.hashtag}</a>
    {/if}
  {/each}
</span>
