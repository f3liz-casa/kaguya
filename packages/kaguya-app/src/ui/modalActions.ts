// SPDX-License-Identifier: MPL-2.0
//
// Reusable Svelte actions for modal-like UI: focus trap, Escape key
// dismissal, body scroll lock, and outside-click dismissal. Each
// action is independent — a modal composes whichever it needs.
//
// `focusTrap` is the old `ui/focusTrap.ts` extended with an `initial`
// option (replaces the hardcoded textarea preference); the other
// three are extracted from inline patterns previously duplicated in
// Layout.svelte (compose modal) and ImageLightbox.svelte.

import type { Action } from 'svelte/action'

const FOCUSABLE_SELECTOR =
  'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])'

// `'textarea'`: pick the first visible textarea, else first focusable.
// `'first'`: pick the first focusable regardless of tag.
// `(node) => HTMLElement | null`: caller-supplied resolver run against
// the trap's container.
export type FocusTrapInitial = 'textarea' | 'first' | ((node: HTMLElement) => HTMLElement | null)
export type FocusTrapOptions = { initial?: FocusTrapInitial } | undefined

export const focusTrap: Action<HTMLElement, FocusTrapOptions> = (node, options) => {
  const prevFocus = document.activeElement as HTMLElement | null
  let mode: FocusTrapInitial = options?.initial ?? 'textarea'

  function focusables(): HTMLElement[] {
    return Array.from(node.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR)).filter(
      (el) => el.offsetParent !== null || el === document.activeElement,
    )
  }

  function pickInitial(): HTMLElement | undefined {
    const list = focusables()
    if (typeof mode === 'function') return mode(node) ?? list[0]
    if (mode === 'first') return list[0]
    return list.find((el) => el.tagName === 'TEXTAREA') ?? list[0]
  }

  pickInitial()?.focus()

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
    update(next) {
      mode = next?.initial ?? 'textarea'
    },
    destroy() {
      document.removeEventListener('keydown', onKey)
      prevFocus?.focus()
    },
  }
}

// Fires the callback when Escape is pressed anywhere. `stopPropagation`
// keeps an inner modal from leaking the key to an outer one.
export const escapeKey: Action<HTMLElement, () => void> = (_node, onEscape) => {
  let cb = onEscape
  function onKey(e: KeyboardEvent) {
    if (e.key !== 'Escape') return
    e.stopPropagation()
    cb()
  }
  document.addEventListener('keydown', onKey)
  return {
    update(next) {
      cb = next
    },
    destroy() {
      document.removeEventListener('keydown', onKey)
    },
  }
}

// Locks `document.body.style.overflow` for the lifetime of the node.
// On destroy restores the previous value (string-equal, so empty stays
// empty rather than collapsing to default).
export const scrollLock: Action<HTMLElement> = () => {
  const prev = document.body.style.overflow
  document.body.style.overflow = 'hidden'
  return {
    destroy() {
      document.body.style.overflow = prev
    },
  }
}

// Fires the callback on `mousedown` outside the node. `mousedown`
// (not `click`) avoids the "drag started inside, ended outside" false
// positive. The trigger button that opens the modal won't re-fire
// because the action only attaches after the modal mounts.
export const outsideClick: Action<HTMLElement, () => void> = (node, onOutside) => {
  let cb = onOutside
  function onDown(e: MouseEvent) {
    if (!(e.target instanceof Node)) return
    if (node.contains(e.target)) return
    cb()
  }
  document.addEventListener('mousedown', onDown)
  return {
    update(next) {
      cb = next
    },
    destroy() {
      document.removeEventListener('mousedown', onDown)
    },
  }
}
