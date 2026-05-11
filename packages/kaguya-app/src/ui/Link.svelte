<!--
  SPDX-License-Identifier: MPL-2.0

  Client-side anchor for the Svelte tree. Mirrors router.tsx's Link
  semantics: left-click without modifier keys → preventDefault and
  navigate(href); everything else (modified keys, middle-click,
  right-click) falls through to native browser behavior.
-->

<script lang="ts">
  import type { Snippet } from 'svelte'
  import { navigate } from './svelteRouter'

  type Props = {
    href: string
    class?: string
    children: Snippet
    onclick?: (e: MouseEvent) => void
  }
  let { href, class: className, children, onclick }: Props = $props()

  function handle(e: MouseEvent) {
    const modified = e.ctrlKey || e.metaKey || e.altKey || e.shiftKey
    if (!modified && e.button === 0) {
      e.preventDefault()
      onclick?.(e)
      navigate(href)
    }
  }
</script>

<a {href} class={className} onclick={handle}>
  {@render children()}
</a>
