<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of SocialRenderer's renderNode (block-level dispatch).
  block-type branches handled here; inline-typed nodes fall through
  to SocialInline. blockquote children recurse via self-import.
-->

<script lang="ts">
  import type { SocialNode, SocialInline as SocialInlineType } from './socialNode'
  import type { FetchPriority } from '../../infra/fetchQueue'
  import SocialInline from './SocialInline.svelte'
  import Self from './SocialBlock.svelte'
  import { currentLocale, t } from '../../infra/i18n'
  import { svelteSignal } from '../svelteSignal.svelte'

  type Props = { node: SocialNode; contextHost: string; priority: FetchPriority }
  let { node, contextHost, priority }: Props = $props()

  const localeR = svelteSignal(currentLocale)
  const searchLabel = $derived((localeR.value, t('mfm.search_button')))
</script>

{#if node.type === 'paragraph'}
  <p>{#each node.children as child, i (i)}<SocialInline node={child} {contextHost} {priority} />{/each}</p>
{:else if node.type === 'blockquote'}
  <blockquote class="mfm-quote">{#each node.children as child, i (i)}<Self node={child} {contextHost} {priority} />{/each}</blockquote>
{:else if node.type === 'code'}
  <pre class="mfm-code-block"><code class={node.lang ? `language-${node.lang}` : undefined}>{node.value}</code></pre>
{:else if node.type === 'center'}
  <div class="mfm-center">{#each node.children as child, i (i)}<SocialInline node={child} {contextHost} {priority} />{/each}</div>
{:else if node.type === 'mathBlock'}
  <div class="mfm-math-block">{`\\[${node.value}\\]`}</div>
{:else if node.type === 'search'}
  <div class="mfm-search">
    <span>{node.query}</span>
    <button class="mfm-search-button">{searchLabel}</button>
  </div>
{:else}
  <SocialInline node={node as SocialInlineType} {contextHost} {priority} />
{/if}
