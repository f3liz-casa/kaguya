// SPDX-License-Identifier: MPL-2.0
//
// Bluesky AT Protocol OAuth2 flow.
// Uses @atproto/oauth-client-browser which handles DPoP, PAR, PKCE,
// token refresh, and session storage (IndexedDB) internally.

import { BrowserOAuthClient } from '@atproto/oauth-client-browser'
import type { OAuthSession } from '@atproto/oauth-client-browser'
import type { LoginError } from './authTypes'
import type { Result } from '../../infra/result'
import { ok, err } from '../../infra/result'
import * as storage from '../../infra/storage'
import { authState } from './appState'
import { loginBluesky } from './authService'

let oauthClient: BrowserOAuthClient | undefined

function isLoopback(): boolean {
  const origin = window.location.origin
  return origin.startsWith('http://localhost') || origin.startsWith('http://127.0.0.1')
}

/** AT Protocol loopback clients must use http://127.0.0.1 for redirect URIs */
function redirectUri(): string {
  if (isLoopback()) {
    const port = window.location.port
    return `http://127.0.0.1${port ? `:${port}` : ''}/oauth-callback`
  }
  return `${window.location.origin}/oauth-callback`
}

function clientId(): string {
  if (isLoopback()) {
    // AT Protocol loopback client_id format: http://localhost?redirect_uri=...&scope=...
    const redirect = encodeURIComponent(redirectUri())
    return `http://localhost?redirect_uri=${redirect}&scope=${encodeURIComponent('atproto transition:generic')}`
  }
  // For production, point to the served client-metadata.json
  return `${window.location.origin}/client-metadata.json`
}

export async function initOAuthClient(): Promise<BrowserOAuthClient> {
  if (oauthClient) return oauthClient
  oauthClient = new BrowserOAuthClient({
    handleResolver: 'https://bsky.social',
    clientMetadata: {
      client_id: clientId(),
      client_name: 'Kaguya',
      client_uri: window.location.origin,
      redirect_uris: [redirectUri()],
      grant_types: ['authorization_code', 'refresh_token'],
      response_types: ['code'],
      scope: 'atproto transition:generic',
      dpop_bound_access_tokens: true,
      token_endpoint_auth_method: 'none',
      application_type: 'web',
    },
  })
  return oauthClient
}

export async function startBlueskyOAuth2(opts: { handle: string }): Promise<Result<void, LoginError>> {
  try {
    const client = await initOAuthClient()
    storage.set(storage.keyOAuth2Backend, 'bluesky')
    // signInRedirect will redirect the browser — it never resolves on success
    await client.signInRedirect(opts.handle, { state: 'bluesky' })
    return ok(undefined)
  } catch (e) {
    console.error('Bluesky OAuth2 error:', e)
    const msg = e instanceof Error ? e.message : 'Bluesky OAuth2 failed'
    authState.value = { type: 'LoginFailed', error: { type: 'NetworkError', message: msg } }
    return err({ type: 'NetworkError', message: msg })
  }
}

/**
 * Clear old sessions from IndexedDB so the library's callback() method
 * won't revoke them. Bluesky's authorization server may revoke all tokens
 * for the same DID+client when any token is revoked, which would
 * invalidate the freshly-obtained tokens.
 */
async function clearOldSessions(): Promise<void> {
  return new Promise<void>((resolve) => {
    try {
      const request = indexedDB.open('@atproto-oauth-client')
      request.onsuccess = () => {
        try {
          const db = request.result
          if (!db.objectStoreNames.contains('session')) { db.close(); resolve(); return }
          const tx = db.transaction('session', 'readwrite')
          tx.objectStore('session').clear()
          tx.oncomplete = () => { db.close(); resolve() }
          tx.onerror = () => { db.close(); resolve() }
        } catch { resolve() }
      }
      request.onerror = () => resolve()
    } catch { resolve() }
  })
}

export async function checkBlueskyOAuth2(): Promise<Result<void, LoginError>> {
  storage.remove(storage.keyOAuth2Backend)
  authState.value = 'LoggingIn'

  try {
    // Clear stored sessions so the library won't revoke old tokens
    // during callback (which can invalidate the new tokens too).
    await clearOldSessions()
    localStorage.removeItem('@@atproto/oauth-client-browser(sub)')

    // Reset the singleton so a fresh client opens the cleaned DB.
    oauthClient = undefined
    const client = await initOAuthClient()

    const result = await client.init()
    if (!result?.session) {
      const msg = 'No session returned from Bluesky OAuth'
      authState.value = { type: 'LoginFailed', error: { type: 'UnknownError', message: msg } }
      return err({ type: 'UnknownError', message: msg })
    }

    window.history.replaceState(null, '', '/')
    return loginBluesky({ session: result.session })
  } catch (e) {
    console.error('Bluesky OAuth2 callback error:', e)
    const msg = e instanceof Error ? e.message : 'Bluesky OAuth2 callback failed'
    authState.value = { type: 'LoginFailed', error: { type: 'NetworkError', message: msg } }
    return err({ type: 'NetworkError', message: msg })
  }
}

export async function restoreBlueskySession(did: string): Promise<OAuthSession | undefined> {
  try {
    const client = await initOAuthClient()
    return await client.restore(did)
  } catch {
    return undefined
  }
}
