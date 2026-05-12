// SPDX-License-Identifier: MPL-2.0
//
// Svelte action: focus-trap a modal-like element. Use as
// `<div use:focusTrap>...</div>` on the modal's outermost focusable
// container. On mount: focuses the first textarea (or first focusable
// fallback) inside the node. On Tab/Shift+Tab: cycles focus inside
// the node. On destroy: restores focus to whatever element was
// active before the modal opened.
//
// Mirrors the Preact compose-modal focus trap from Layout.tsx
// (commit 52b48d8) — same focusable selector, same Tab cycling
// semantics, same prevFocus restore.

import type { Action } from 'svelte/action'

const FOCUSABLE_SELECTOR =
  'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])'

export const focusTrap: Action<HTMLElement> = (node) => {
  const prevFocus = document.activeElement as HTMLElement | null

  function focusables(): HTMLElement[] {
    return Array.from(node.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR)).filter(
      (el) => el.offsetParent !== null || el === document.activeElement,
    )
  }

  const initialList = focusables()
  const initial = initialList.find((el) => el.tagName === 'TEXTAREA') ?? initialList[0]
  initial?.focus()

  function onKey(e: KeyboardEvent) {
    if (e.key !== 'Tab') return
    const list = focusables()
    if (list.length === 0) return
    const first = list[0]
    const last = list[list.length - 1]
    const active = document.activeElement as HTMLElement | null
    const insideModal = active != null && node.contains(active)
    if (e.shiftKey && (active === first || !insideModal)) {
      e.preventDefault()
      last.focus()
    } else if (!e.shiftKey && (active === last || !insideModal)) {
      e.preventDefault()
      first.focus()
    }
  }

  document.addEventListener('keydown', onKey)

  return {
    destroy() {
      document.removeEventListener('keydown', onKey)
      prevFocus?.focus()
    },
  }
}
