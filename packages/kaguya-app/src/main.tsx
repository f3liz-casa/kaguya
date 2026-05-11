// SPDX-License-Identifier: MPL-2.0

import './infra/notePrefetch' // Start note prefetch ASAP (parallel with auth)
import 'virtual:uno.css'
import '@unocss/reset/normalize.css'
import '@kaguya-src/icons.ts'
import { render, hydrate } from 'preact'
import { Serwist } from '@serwist/window'
import { KaguyaApp } from './KaguyaApp'
import { showInfoWithAction } from './ui/toastState'
import { init as i18nInit, t } from './infra/i18n'

// Initialize i18n early so t() works in SW update toast
if (typeof window !== 'undefined') i18nInit()

// Service-worker registration — only in a real browser, not during prerender.
if (typeof window !== 'undefined' && 'serviceWorker' in navigator) {
  const serwist = new Serwist('/sw.js')
  serwist.addEventListener('waiting', () => {
    showInfoWithAction(t('app.new_version'), {
      label: t('app.update_now'),
      onClick: () => serwist.messageSkipWaiting(),
    })
  })
  serwist.addEventListener('controlling', () => window.location.reload())
  serwist.register()
}

const isBrowser = typeof window !== 'undefined'

if (isBrowser) {
  const root = document.getElementById('root')
  if (root) {
    hydrate(<KaguyaApp />, root)
  } else {
    console.error('Could not find root element')
  }
}

// ---------------------------------------------------------------------------
// SSR prerender entry — called by @preact/preset-vite for each baked route.
// ---------------------------------------------------------------------------

export async function prerender(data: { url?: string }): Promise<{ html: string }> {
  const { default: isoPrerender, locationStub } = await import('preact-iso/prerender')
  if (data.url) locationStub(data.url)
  try {
    return await isoPrerender(<KaguyaApp />)
  } catch (e) {
    console.error('[prerender] Error:', e instanceof Error ? e.message : e)
    if (e instanceof Error && e.stack) {
      console.error('[prerender] Stack:', e.stack)
    } else {
      console.error('[prerender] Full:', JSON.stringify(e, null, 2))
    }
    // Re-throw to let the plugin show the detailed source map location
    throw e
  }
}
