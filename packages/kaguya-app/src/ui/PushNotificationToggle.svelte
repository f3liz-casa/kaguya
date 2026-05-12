<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of PushNotificationToggle.tsx. Not yet mounted at
  runtime — PushNotificationToggle.tsx remains the live component
  until M1 mount swap.
-->

<script lang="ts">
  import { state, generateScript, unsubscribe, confirmSubscribed } from '../domain/notification/pushNotificationStore'
  import { client, activeAccountId } from '../domain/auth/appState'
  import { origin as backendOrigin } from '../lib/backend'
  import { currentLocale, t } from '../infra/i18n'
  import { svelteSignal } from './svelteSignal.svelte'

  const stateR = svelteSignal(state)
  const clientR = svelteSignal(client)
  const activeIdR = svelteSignal(activeAccountId)
  const localeR = svelteSignal(currentLocale)

  // Locale-keyed label bundle — `localeR.value` read in the $derived
  // ties every t() call below to the locale signal in one go.
  const L = $derived((localeR.value, {
    unsupported: t('push.unsupported'),
    permissionDenied: t('push.permission_denied'),
    generating: t('push.generating'),
    disable: t('push.disable'),
    enable: t('push.enable'),
    reloadRetry: t('push.reload_retry'),
    scriptInstructions: t('push.script_instructions'),
    copy: t('action.copy'),
    openScratchpad: t('push.open_scratchpad'),
    executed: t('push.executed'),
    cancel: t('action.cancel'),
  }))

  function handleEnable() {
    const c = clientR.value
    const id = activeIdR.value
    if (c && id) void generateScript(c, id)
  }
  function handleDisable() {
    const c = clientR.value
    const id = activeIdR.value
    if (c && id) void unsubscribe(c, id)
  }
  function handleConfirm() {
    const id = activeIdR.value
    if (id) confirmSubscribed(id)
  }
  function handleCopy(script: string) {
    void navigator.clipboard.writeText(script)
  }
  function openScratchpad() {
    const c = clientR.value
    if (c) window.open(backendOrigin(c) + '/scratchpad', '_blank')
  }
</script>

{#if typeof window !== 'undefined'}
  {@const s = stateR.value}
  {#if s === 'NotSupported'}
    <button class="push-notification-toggle" disabled type="button">🚫 {L.unsupported}</button>
  {:else if s === 'PermissionDenied'}
    <button class="push-notification-toggle" disabled type="button">🚫 {L.permissionDenied}</button>
  {:else if s === 'GeneratingScript'}
    <button class="push-notification-toggle" disabled type="button">⏳ {L.generating}</button>
  {:else if s === 'Subscribed'}
    <button class="push-notification-toggle" type="button" onclick={handleDisable}>🔔 {L.disable}</button>
  {:else if s === 'Unsubscribed'}
    <button class="push-notification-toggle" type="button" onclick={handleEnable}>🔕 {L.enable}</button>
  {:else if typeof s === 'object' && s.tag === 'Error'}
    <button class="push-notification-toggle" type="button" onclick={handleEnable}>
      ⚠️ {s.message.includes('reload') ? L.reloadRetry : L.enable}
    </button>
  {:else if typeof s === 'object' && s.tag === 'AwaitingScript'}
    {@const script = s.script}
    <div class="push-script-container" style="display:flex;flex-direction:column;gap:8px">
      <p style="margin:0;font-size:13px">{L.scriptInstructions}</p>
      <textarea readonly value={script} rows={6} style="font-family:monospace;font-size:11px;resize:vertical"></textarea>
      <div style="display:flex;gap:8px;flex-wrap:wrap">
        <button type="button" onclick={() => handleCopy(script)}>📋 {L.copy}</button>
        <button type="button" onclick={openScratchpad}>🔗 {L.openScratchpad}</button>
        <button class="button-primary" type="button" onclick={handleConfirm}>✓ {L.executed}</button>
        <button type="button" onclick={handleDisable}>{L.cancel}</button>
      </div>
    </div>
  {/if}
{/if}
