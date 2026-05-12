// SPDX-License-Identifier: MPL-2.0
//
// Native Misskey push notifications via AiScript + sw/register.
//
// Because Misskey blocks sw/register from third-party OAuth tokens,
// we generate an AiScript that the user runs in Misskey's Scratchpad.
// The script subscribes the browser and calls sw/register on the user's
// behalf using their full Misskey session.
//
// Flow:
//   1. Fetch instance VAPID key from /api/meta (swPublickey)
//   2. Subscribe browser to push using that VAPID key
//   3. Generate AiScript containing the endpoint/keys
//   4. User copies AiScript → runs in Misskey Scratchpad → sw/register called
//   5. User confirms → state becomes Subscribed

import { signal } from '@preact/signals-core'
import type { MisskeyClient } from '../../lib/misskey'
import type { BackendClient } from '../../lib/backend'
import type { Result } from '../../infra/result'
import { ok, err } from '../../infra/result'

export type PushState =
  | 'NotSupported'
  | 'PermissionDenied'
  | 'Unsubscribed'
  | 'GeneratingScript'
  | { tag: 'AwaitingScript'; script: string }
  | 'Subscribed'
  | { tag: 'Error'; message: string }

export const state = signal<PushState>('NotSupported')

const storageKeyPrefix = 'kaguya:nativePushEnabled:'
const endpointPrefix = 'kaguya:nativePushEndpoint:'

function isServiceWorkerSupported(): boolean {
  return typeof navigator !== 'undefined' && 'serviceWorker' in navigator
}

function isNotificationSupported(): boolean {
  return typeof Notification !== 'undefined'
}

function getPermission(): NotificationPermission | undefined {
  if (typeof Notification === 'undefined') return undefined
  return Notification.permission
}

export function init(): void {
  if (!isServiceWorkerSupported() || !isNotificationSupported()) {
    state.value = 'NotSupported'
  } else if (getPermission() === 'denied') {
    state.value = 'PermissionDenied'
  } else {
    state.value = 'Unsubscribed'
  }
}

function buildAiScript(opts: {
  expectedUsername: string
  misskeyOrigin: string
  endpoint: string
  auth: string
  p256dh: string
}): string {
  const { expectedUsername, misskeyOrigin, endpoint, auth, p256dh } = opts
  return `/// @ 0.18.0
// Generated for @${expectedUsername} on ${misskeyOrigin}

if ((USER_USERNAME != '${expectedUsername}') || ((SERVER_URL != '${misskeyOrigin}/') && (SERVER_URL != '${misskeyOrigin}'))) {
  Mk:dialog('Validation Failed', 'Account/Host mismatch.', 'error')
  Core:abort()
}

let response = Mk:api('sw/register', {
  endpoint: '${endpoint}',
  auth: '${auth}',
  publickey: '${p256dh}',
})

if (Core:type(response) == 'error') {
  Mk:dialog('Registration Failed', Core:to_str(response.info), 'error')
} else {
  Mk:dialog('Success!', 'Push notifications enabled. You can close this window.', 'success')
}`
}

function encodeBase64Url(buffer: ArrayBuffer): string {
  if (typeof btoa === 'undefined' || typeof Uint8Array === 'undefined') {
    throw new Error('encodeBase64Url requires browser APIs')
  }
  const bytes = new Uint8Array(buffer)
  let str = ''
  bytes.forEach(b => { str += String.fromCharCode(b) })
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}

export async function generateScript(bc: BackendClient, accountId: string): Promise<Result<void>> {
  if (bc.backend !== 'misskey') return err('Push notifications are only supported for Misskey accounts')
  const client = bc.client
  if (!isServiceWorkerSupported() || !isNotificationSupported()) {
    return err('Push notifications not supported in this browser')
  }

  state.value = 'GeneratingScript'
  try {
    // Lazy import Meta to avoid issues during SSR/prerendering
    const { Meta } = await import('../../lib/misskey')
    const metaResult = await Meta.get(client)
    if (!metaResult.ok) {
      state.value = { tag: 'Error', message: metaResult.error }
      return err(`Failed to fetch instance meta: ${metaResult.error}`)
    }

    const vapidKey = metaResult.value.swPublickey
    if (!vapidKey) {
      state.value = 'NotSupported'
      return err('Push notifications not enabled on this instance')
    }

    const perm = await Notification.requestPermission()
    if (perm === 'denied') {
      state.value = 'PermissionDenied'
      return err('Notification permission denied')
    }

    const registration = await navigator.serviceWorker.ready
    if (!navigator.serviceWorker.controller) {
      state.value = { tag: 'Error', message: 'Service Worker is not yet controlling this page. Please reload and try again.' }
      return err('Service Worker not controlling page')
    }

    const pm = registration.pushManager
    const existing = await pm.getSubscription().catch(() => null)
    if (existing) await existing.unsubscribe().catch(() => false)

    const applicationServerKey = Uint8Array.from(
      atob(vapidKey.replace(/-/g, '+').replace(/_/g, '/')),
      c => c.charCodeAt(0)
    )
    const subscription = await pm.subscribe({ userVisibleOnly: true, applicationServerKey })
    const endpoint = subscription.endpoint
    const p256dhKey = subscription.getKey('p256dh')
    const authKey = subscription.getKey('auth')
    if (!p256dhKey || !authKey) {
      return err('Failed to get push subscription keys')
    }
    const p256dh = encodeBase64Url(p256dhKey)
    const auth = encodeBase64Url(authKey)

    // Get username for AiScript validation — call /api/i directly
    const { request: misskeyRequest } = await import('../../lib/misskey')
    const userResult = await misskeyRequest(client, 'i')
    let username = 'unknown'
    if (userResult.ok) {
      const userObj = userResult.value as Record<string, unknown>
      username = typeof userObj['username'] === 'string' ? userObj['username'] : 'unknown'
    }

    const misskeyOrigin = client.origin
    const script = buildAiScript({ expectedUsername: username, misskeyOrigin, endpoint, auth, p256dh })

    localStorage.setItem(endpointPrefix + accountId, endpoint)
    state.value = { tag: 'AwaitingScript', script }
    return ok(undefined)
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'Unknown error'
    console.error('[PushNotification] generateScript failed:', e)
    state.value = { tag: 'Error', message: msg }
    return err(`Script generation failed: ${msg}`)
  }
}

export function confirmSubscribed(accountId: string): void {
  localStorage.setItem(storageKeyPrefix + accountId, 'true')
  state.value = 'Subscribed'
}

export async function unsubscribe(_client: BackendClient, accountId: string): Promise<Result<void>> {
  try {
    if (isServiceWorkerSupported()) {
      const registration = await navigator.serviceWorker.ready
      const existing = await registration.pushManager.getSubscription().catch(() => null)
      if (existing) await existing.unsubscribe()
    }
    localStorage.removeItem(storageKeyPrefix + accountId)
    localStorage.removeItem(endpointPrefix + accountId)
    state.value = 'Unsubscribed'
    return ok(undefined)
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'Unknown error'
    return err(`Push unsubscribe failed: ${msg}`)
  }
}

export function isEnabledForAccount(accountId: string): boolean {
  return localStorage.getItem(storageKeyPrefix + accountId) === 'true'
}

export async function restore(bc: BackendClient, accountId: string): Promise<void> {
  if (bc.backend !== 'misskey') return
  const client = bc.client
  init()
  if (!isEnabledForAccount(accountId) || !isServiceWorkerSupported()) return
  try {
    const registration = await navigator.serviceWorker.ready
    const existing = await registration.pushManager.getSubscription().catch(() => null)
    if (existing) {
      state.value = 'Subscribed'
    } else {
      localStorage.removeItem(storageKeyPrefix + accountId)
      if (getPermission() === 'granted') {
        await generateScript(bc, accountId)
      } else {
        state.value = 'Unsubscribed'
      }
    }
  } catch (e) {
    console.error('[PushNotification] restore failed:', e)
    state.value = 'Unsubscribed'
  }
}
