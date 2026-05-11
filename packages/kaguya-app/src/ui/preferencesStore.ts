// SPDX-License-Identifier: MPL-2.0

import { signal, computed, effect } from '@preact/signals'
import {
  keyFontSize,
  keyReduceMotion,
  keyQuietMode,
  keyQuietHoursEnabled,
  keyQuietHoursStart,
  keyQuietHoursEnd,
  keyStreamingEnabled,
  keyDefaultNoteVisibility,
  keyDefaultRenoteVisibility,
  keyHideNsfw,
} from '../infra/storage'
import type { Visibility } from '../lib/backend'

export type FontSize = 'small' | 'medium' | 'large'

export const fontSize = signal<FontSize>('medium')
export const reduceMotion = signal(false)
// Manual quiet-mode override (sidebar toggle). The *effective* quiet state is
// `isQuiet`, which folds in the quiet-hours schedule as well.
export const quietMode = signal(false)
// New-user default: on. Existing installs seeded to `false` via the migration.
export const quietHoursEnabled = signal(true)
export const quietHoursStart = signal('22:00')  // HH:mm local
export const quietHoursEnd = signal('07:00')
// New-user default: off. Existing installs seeded to `true` via the migration.
export const streamingEnabled = signal(false)
export const defaultNoteVisibility = signal<Visibility>('public')
export const defaultRenoteVisibility = signal<Visibility>('public')
export const hideNsfw = signal(false)

// Ticks every minute so `isQuietHoursActive` recomputes on schedule boundaries.
const clockTick = signal(0)

export const isQuietHoursActive = computed<boolean>(() => {
  // Establish dependency so the computed is reactive to clock ticks.
  const _ = clockTick.value
  void _
  if (!quietHoursEnabled.value) return false
  const now = new Date()
  const minutes = now.getHours() * 60 + now.getMinutes()
  const [sh, sm] = quietHoursStart.value.split(':').map(Number)
  const [eh, em] = quietHoursEnd.value.split(':').map(Number)
  if (Number.isNaN(sh) || Number.isNaN(sm) || Number.isNaN(eh) || Number.isNaN(em)) return false
  const start = sh * 60 + sm
  const end = eh * 60 + em
  // Wrap past midnight when end < start.
  return start <= end
    ? (minutes >= start && minutes < end)
    : (minutes >= start || minutes < end)
})

// The effective "quiet" state. Read this from UI, not `quietMode` directly.
export const isQuiet = computed<boolean>(() => quietMode.value || isQuietHoursActive.value)

function applyFontSize(size: FontSize): void {
  if (typeof document === 'undefined') return
  if (size === 'medium') {
    document.documentElement.removeAttribute('data-font-size')
  } else {
    document.documentElement.setAttribute('data-font-size', size)
  }
}

function applyReduceMotion(enabled: boolean): void {
  if (typeof document === 'undefined') return
  if (enabled) {
    document.documentElement.setAttribute('data-reduce-motion', '')
  } else {
    document.documentElement.removeAttribute('data-reduce-motion')
  }
}

function applyQuietMode(enabled: boolean): void {
  if (typeof document === 'undefined') return
  if (enabled) {
    document.documentElement.setAttribute('data-quiet-mode', '')
  } else {
    document.documentElement.removeAttribute('data-quiet-mode')
  }
}

function isValidTime(value: string): boolean {
  return /^\d{2}:\d{2}$/.test(value)
}

const visibilityValues: Visibility[] = ['public', 'home', 'followers', 'specified']

export function init(): void {
  if (typeof localStorage === 'undefined') return

  // One-time migration: preserve loud defaults for existing installs.
  // Any kaguya:* key means "existing user" — they expect streaming on and quiet
  // hours off. Missing keys + empty storage = "new user" — they get calm defaults.
  const hasExistingInstall = Object.keys(localStorage).some(k => k.startsWith('kaguya:'))
  if (localStorage.getItem(keyStreamingEnabled) === null) {
    localStorage.setItem(keyStreamingEnabled, hasExistingInstall ? 'true' : 'false')
  }
  if (localStorage.getItem(keyQuietHoursEnabled) === null) {
    localStorage.setItem(keyQuietHoursEnabled, hasExistingInstall ? 'false' : 'true')
  }

  const storedSize = localStorage.getItem(keyFontSize)
  if (storedSize === 'small' || storedSize === 'large') {
    fontSize.value = storedSize
  }
  applyFontSize(fontSize.value)

  const storedMotion = localStorage.getItem(keyReduceMotion)
  if (storedMotion === 'true') {
    reduceMotion.value = true
  }
  applyReduceMotion(reduceMotion.value)

  const storedQuiet = localStorage.getItem(keyQuietMode)
  if (storedQuiet === 'true') {
    quietMode.value = true
  }

  const storedQuietHoursEnabled = localStorage.getItem(keyQuietHoursEnabled)
  quietHoursEnabled.value = storedQuietHoursEnabled === 'true'
  const storedQuietStart = localStorage.getItem(keyQuietHoursStart)
  if (storedQuietStart && isValidTime(storedQuietStart)) quietHoursStart.value = storedQuietStart
  const storedQuietEnd = localStorage.getItem(keyQuietHoursEnd)
  if (storedQuietEnd && isValidTime(storedQuietEnd)) quietHoursEnd.value = storedQuietEnd

  // Reflect the effective quiet state (manual OR schedule) into the DOM. This
  // `effect` runs once here to prime it, then continues to react for the app lifetime.
  effect(() => applyQuietMode(isQuiet.value))

  // Advance clockTick every minute so quiet-hours transitions take effect.
  if (typeof window !== 'undefined') {
    window.setInterval(() => { clockTick.value = clockTick.value + 1 }, 60_000)
  }

  const storedStreaming = localStorage.getItem(keyStreamingEnabled)
  streamingEnabled.value = storedStreaming === 'true'

  const storedNoteVis = localStorage.getItem(keyDefaultNoteVisibility) as Visibility | null
  if (storedNoteVis && visibilityValues.includes(storedNoteVis)) {
    defaultNoteVisibility.value = storedNoteVis
  }

  const storedRenoteVis = localStorage.getItem(keyDefaultRenoteVisibility) as Visibility | null
  if (storedRenoteVis && visibilityValues.includes(storedRenoteVis)) {
    defaultRenoteVisibility.value = storedRenoteVis
  }

  const storedHideNsfw = localStorage.getItem(keyHideNsfw)
  if (storedHideNsfw === 'true') {
    hideNsfw.value = true
  }
}

export function setFontSize(size: FontSize): void {
  fontSize.value = size
  applyFontSize(size)
  if (typeof localStorage === 'undefined') return
  if (size === 'medium') localStorage.removeItem(keyFontSize)
  else localStorage.setItem(keyFontSize, size)
}

export function setReduceMotion(enabled: boolean): void {
  reduceMotion.value = enabled
  applyReduceMotion(enabled)
  if (typeof localStorage === 'undefined') return
  if (enabled) localStorage.setItem(keyReduceMotion, 'true')
  else localStorage.removeItem(keyReduceMotion)
}

export function setQuietMode(enabled: boolean): void {
  quietMode.value = enabled
  if (typeof localStorage === 'undefined') return
  if (enabled) localStorage.setItem(keyQuietMode, 'true')
  else localStorage.removeItem(keyQuietMode)
}

export function toggleQuietMode(): void {
  setQuietMode(!quietMode.value)
}

export function setQuietHoursEnabled(enabled: boolean): void {
  quietHoursEnabled.value = enabled
  if (typeof localStorage === 'undefined') return
  localStorage.setItem(keyQuietHoursEnabled, enabled ? 'true' : 'false')
}

export function setQuietHoursStart(value: string): void {
  if (!isValidTime(value)) return
  quietHoursStart.value = value
  if (typeof localStorage === 'undefined') return
  localStorage.setItem(keyQuietHoursStart, value)
}

export function setQuietHoursEnd(value: string): void {
  if (!isValidTime(value)) return
  quietHoursEnd.value = value
  if (typeof localStorage === 'undefined') return
  localStorage.setItem(keyQuietHoursEnd, value)
}

export function setStreamingEnabled(enabled: boolean): void {
  streamingEnabled.value = enabled
  if (typeof localStorage === 'undefined') return
  localStorage.setItem(keyStreamingEnabled, enabled ? 'true' : 'false')
}

export function setDefaultNoteVisibility(v: Visibility): void {
  defaultNoteVisibility.value = v
  if (typeof localStorage === 'undefined') return
  localStorage.setItem(keyDefaultNoteVisibility, v)
}

export function setDefaultRenoteVisibility(v: Visibility): void {
  defaultRenoteVisibility.value = v
  if (typeof localStorage === 'undefined') return
  localStorage.setItem(keyDefaultRenoteVisibility, v)
}

export function setHideNsfw(enabled: boolean): void {
  hideNsfw.value = enabled
  if (typeof localStorage === 'undefined') return
  if (enabled) localStorage.setItem(keyHideNsfw, 'true')
  else localStorage.removeItem(keyHideNsfw)
}
