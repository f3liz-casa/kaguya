// SPDX-License-Identifier: MPL-2.0
//
// Mini SPA router for the Svelte tree. Mirrors the surface used by
// router.tsx (preact-iso wrapper): a `[path, navigate]` pair and a
// navigate function. Routes are matched in the App.svelte template
// (no <Router> component) — the consumer reads `currentPath` and
// branches with {#if} / {:else if} blocks.
//
// Uses @preact/signals-core so the signal can be wired into Svelte
// via svelteSignal — same bridge as every other domain signal.

import { signal, type ReadonlySignal } from '@preact/signals-core'

const initialPath = typeof window !== 'undefined' ? window.location.pathname : '/'
const _currentPath = signal<string>(initialPath)

export const currentPath: ReadonlySignal<string> = _currentPath

if (typeof window !== 'undefined') {
  window.addEventListener('popstate', () => {
    _currentPath.value = window.location.pathname
  })
}

export function navigate(path: string, replace = false): void {
  if (typeof window === 'undefined') return
  if (replace) window.history.replaceState(null, '', path)
  else window.history.pushState(null, '', path)
  _currentPath.value = path
}
