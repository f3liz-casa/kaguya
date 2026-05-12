<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of LoadingBar.tsx. Not yet mounted at runtime —
  LoadingBar.tsx remains the live component until M1 mount swap.
-->

<script lang="ts">
  import { onMount } from 'svelte'
  import { isLoading } from '../pageLoading'
  import { svelteSignal } from './svelteSignal.svelte'

  const loadingR = svelteSignal(isLoading)
  let completing = $state(false)
  // Non-reactive cell mirroring useRef — only $effect reads/writes it,
  // template doesn't need to re-evaluate when it flips.
  let everActive = false

  onMount(() => {
    const el = document.getElementById('initial-bar')
    if (el) el.remove()
  })

  $effect(() => {
    const loading = loadingR.value
    if (loading) {
      everActive = true
      completing = false
    } else if (everActive) {
      everActive = false
      completing = true
      const t = setTimeout(() => { completing = false }, 600)
      return () => clearTimeout(t)
    }
  })
</script>

{#if loadingR.value}
  <div class="page-loading-bar page-loading-bar--active"></div>
{:else if completing}
  <div class="page-loading-bar page-loading-bar--completing"></div>
{/if}
