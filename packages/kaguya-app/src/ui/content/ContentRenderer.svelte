<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of ContentRenderer.tsx. Drop-in replacement for the
  parseSimple-only subset that landed in M1 part 5a — now full
  surface ({ text, contentType?, parseSimple?, contextHost?, facets? })
  matching the Preact API, dispatching parsers (fromMfm / fromHtml /
  fromFacets) and rendering through SocialRenderer.

  Element tag (`<span>` vs `<div>`) tracks parseSimple, same as the
  Preact original — inline contexts keep span semantics.
-->

<script lang="ts">
  import type { ContentType } from '../../domain/note/noteView'
  import type { BlueskyFacet } from './fromFacets'
  import type { FetchPriority } from '../../infra/fetchQueue'
  import { fromMfm } from './fromMfm'
  import { fromHtml } from './fromHtml'
  import { fromFacets } from './fromFacets'
  import SocialRenderer from './SocialRenderer.svelte'
  import { instanceName } from '../../domain/auth/appState'
  import * as mfm from 'mfm-js'
  import { svelteSignal } from '../svelteSignal.svelte'

  type Props = {
    text: string
    contentType?: ContentType
    parseSimple?: boolean
    contextHost?: string
    facets?: BlueskyFacet[]
  }
  let { text, contentType = 'mfm', parseSimple = false, contextHost, facets }: Props = $props()

  const instanceR = svelteSignal(instanceName)
  const ctxHost = $derived(contextHost ?? instanceR.value)
  const priority = $derived<FetchPriority>(parseSimple ? 3 : 1)

  const nodes = $derived.by(() => {
    if (contentType === 'mfm') {
      const parsed = parseSimple ? mfm.parseSimple(text) : mfm.parse(text)
      return fromMfm(parsed as Parameters<typeof fromMfm>[0])
    }
    if (contentType === 'html') {
      return fromHtml(text)
    }
    return fromFacets(text, facets ?? [])
  })
</script>

{#if parseSimple}
  <span class="mfm-content"><SocialRenderer {nodes} contextHost={ctxHost} {priority} /></span>
{:else}
  <div class="mfm-content"><SocialRenderer {nodes} contextHost={ctxHost} {priority} /></div>
{/if}
