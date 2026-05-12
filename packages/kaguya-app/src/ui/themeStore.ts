// SPDX-License-Identifier: MPL-2.0

import { signal } from '@preact/signals-core'

export type Theme = 'Light' | 'Dark' | 'System'

const storageKey = 'kaguya:theme'

export const currentTheme = signal<Theme>('System')

function applyTheme(theme: Theme): void {
  if (typeof document === 'undefined') return
  if (theme === 'Light') {
    document.documentElement.setAttribute('data-theme', 'light')
  } else if (theme === 'Dark') {
    document.documentElement.setAttribute('data-theme', 'dark')
  } else {
    document.documentElement.removeAttribute('data-theme')
  }
}

export function init(): void {
  if (typeof localStorage === 'undefined') return
  const stored = localStorage.getItem(storageKey)
  const theme: Theme = stored === 'light' ? 'Light' : stored === 'dark' ? 'Dark' : 'System'
  currentTheme.value = theme
  applyTheme(theme)
}

export function toggle(): void {
  const current = currentTheme.value
  const sysDark = typeof window !== 'undefined' && window.matchMedia('(prefers-color-scheme: dark)').matches
  let next: Theme
  if (current === 'System') {
    next = sysDark ? 'Light' : 'Dark'
  } else if (current === 'Light') {
    next = 'Dark'
  } else {
    next = 'Light'
  }
  currentTheme.value = next
  applyTheme(next)
  if (typeof localStorage !== 'undefined') {
    if (next === 'Light') localStorage.setItem(storageKey, 'light')
    else if (next === 'Dark') localStorage.setItem(storageKey, 'dark')
    else localStorage.removeItem(storageKey)
  }
}

export function setTheme(theme: Theme): void {
  currentTheme.value = theme
  applyTheme(theme)
  if (typeof localStorage === 'undefined') return
  if (theme === 'Light') localStorage.setItem(storageKey, 'light')
  else if (theme === 'Dark') localStorage.setItem(storageKey, 'dark')
  else localStorage.removeItem(storageKey)
}

export function isDark(): boolean {
  const theme = currentTheme.value
  if (theme === 'Dark') return true
  if (theme === 'Light') return false
  return typeof window !== 'undefined' && window.matchMedia('(prefers-color-scheme: dark)').matches
}
