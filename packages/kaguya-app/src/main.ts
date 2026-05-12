// SPDX-License-Identifier: MPL-2.0

import './infra/notePrefetch' // Start note prefetch ASAP (parallel with auth)
import 'virtual:uno.css'
import '@unocss/reset/normalize.css'
import '@kaguya-src/icons.ts'
import { Serwist } from '@serwist/window'
import { mount } from 'svelte'
import App from './App.svelte'
import { showInfoWithAction } from './ui/toastState'
import { init as i18nInit, t } from './infra/i18n'

if (typeof window !== 'undefined') i18nInit()

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

if (typeof window !== 'undefined') {
  const root = document.getElementById('root')
  if (root) {
    mount(App, { target: root })
  } else {
    console.error('Could not find root element')
  }
}
