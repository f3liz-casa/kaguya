// SPDX-License-Identifier: MPL-2.0

import { state, generateScript, unsubscribe, confirmSubscribed } from '../domain/notification/pushNotificationStore'
import { client, activeAccountId } from '../domain/auth/appState'
import { origin as backendOrigin } from '../lib/backend'
import { t } from '../infra/i18n'

export function PushNotificationToggle() {
  // Only render on client side (required for SSR/prerendering)
  if (typeof window === 'undefined') {
    return null
  }

  const pushState = state.value
  const currentClient = client.value
  const activeId = activeAccountId.value

  function handleEnable() {
    if (currentClient && activeId) {
      void generateScript(currentClient, activeId)
    }
  }

  function handleDisable() {
    if (currentClient && activeId) {
      void unsubscribe(currentClient, activeId)
    }
  }

  function handleConfirm() {
    if (activeId) confirmSubscribed(activeId)
  }

  function handleCopy(script: string) {
    void navigator.clipboard.writeText(script)
  }

  function openScratchpad() {
    if (currentClient) {
      window.open(backendOrigin(currentClient) + '/scratchpad', '_blank')
    }
  }

  if (pushState === 'NotSupported') {
    return <button class="push-notification-toggle" disabled type="button">🚫 {t('push.unsupported')}</button>
  }
  if (pushState === 'PermissionDenied') {
    return <button class="push-notification-toggle" disabled type="button">🚫 {t('push.permission_denied')}</button>
  }
  if (pushState === 'GeneratingScript') {
    return <button class="push-notification-toggle" disabled type="button">⏳ {t('push.generating')}</button>
  }
  if (pushState === 'Subscribed') {
    return <button class="push-notification-toggle" onClick={handleDisable} type="button">🔔 {t('push.disable')}</button>
  }
  if (pushState === 'Unsubscribed' || (typeof pushState === 'object' && pushState.tag === 'Error')) {
    const label = typeof pushState === 'object' && pushState.tag === 'Error'
      ? (pushState.message.includes('reload') ? `⚠️ ${t('push.reload_retry')}` : `⚠️ ${t('push.enable')}`)
      : `🔕 ${t('push.enable')}`
    return <button class="push-notification-toggle" onClick={handleEnable} type="button">{label}</button>
  }
  if (typeof pushState === 'object' && pushState.tag === 'AwaitingScript') {
    const { script } = pushState
    return (
      <div class="push-script-container" style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
        <p style={{ margin: 0, fontSize: '13px' }}>{t('push.script_instructions')}</p>
        <textarea readOnly value={script} rows={6} style={{ fontFamily: 'monospace', fontSize: '11px', resize: 'vertical' }} />
        <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
          <button onClick={() => handleCopy(script)} type="button">📋 {t('action.copy')}</button>
          <button onClick={openScratchpad} type="button">🔗 {t('push.open_scratchpad')}</button>
          <button class="button-primary" onClick={handleConfirm} type="button">✓ {t('push.executed')}</button>
          <button onClick={handleDisable} type="button">{t('action.cancel')}</button>
        </div>
      </div>
    )
  }
  return null
}
