// SPDX-License-Identifier: MPL-2.0

import { signal } from '@preact/signals-core'
import { keyLocale } from './storage'
import { ja } from './locales/ja'
import { en } from './locales/en'

export type Locale = 'ja' | 'en'

const locales: Record<Locale, Record<string, string>> = { ja, en }

export const currentLocale = signal<Locale>('ja')

export function t(key: string): string {
  return locales[currentLocale.value][key] ?? locales['ja'][key] ?? key
}

export function init(): void {
  if (typeof localStorage === 'undefined') return
  const stored = localStorage.getItem(keyLocale)
  if (stored === 'en' || stored === 'ja') {
    currentLocale.value = stored
  } else {
    // Auto-detect from browser language
    if (typeof navigator !== 'undefined') {
      const lang = navigator.language.toLowerCase()
      if (!lang.startsWith('ja')) {
        currentLocale.value = 'en'
      }
    }
  }
}

export function setLocale(locale: Locale): void {
  currentLocale.value = locale
  if (typeof localStorage === 'undefined') return
  localStorage.setItem(keyLocale, locale)
}
