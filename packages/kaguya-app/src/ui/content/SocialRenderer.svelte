<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of SocialRenderer.tsx. SocialNode[] → Svelte DOM via
  SocialBlock (which dispatches to SocialInline for inline-typed
  fall-through). Same IR / same semantics as the Preact renderer.
-->

<script lang="ts">
  import type { SocialNode } from './socialNode'
  import type { FetchPriority } from '../../infra/fetchQueue'
  import SocialBlock from './SocialBlock.svelte'

  type Props = { nodes: SocialNode[]; contextHost: string; priority: FetchPriority }
  let { nodes, contextHost, priority }: Props = $props()
</script>

{#each nodes as node, i (i)}
  <SocialBlock {node} {contextHost} {priority} />
{/each}
