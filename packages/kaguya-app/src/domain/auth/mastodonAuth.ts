// SPDX-License-Identifier: MPL-2.0
//
// Mastodon OAuth2 flow. Mastodon requires per-instance app registration
// before the standard OAuth2 authorize + token exchange.

import type { LoginError } from './authTypes'
import type { Result } from '../../infra/result'
import { ok, err } from '../../infra/result'
import { normalizeOrigin } from '../../infra/urlUtils'
import * as storage from '../../infra/storage'
import { authState } from './appState'
import { login } from './authService'

const APP_NAME = 'Kaguya'
const SCOPES = 'read write follow push'

function redirectUri(): string {
  return `${window.location.origin}/oauth-callback`
}

function clientIdKey(origin: string): string {
  return `kaguya:mastodon:clientId:${origin}`
}

function clientSecretKey(origin: string): string {
  return `kaguya:mastodon:clientSecret:${origin}`
}

async function ensureApp(origin: string): Promise<{ clientId: string; clientSecret: string }> {
  const cachedId = storage.get(clientIdKey(origin))
  const cachedSecret = storage.get(clientSecretKey(origin))
  if (cachedId && cachedSecret) return { clientId: cachedId, clientSecret: cachedSecret }

  const resp = await fetch(`${origin}/api/v1/apps`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_name: APP_NAME,
      redirect_uris: redirectUri(),
      scopes: SCOPES,
      website: window.location.origin,
    }),
  })

  if (!resp.ok) throw new Error(`App registration failed: ${resp.status}`)

  const data = await resp.json()
  const clientId = data.client_id as string
  const clientSecret = data.client_secret as string

  storage.set(clientIdKey(origin), clientId)
  storage.set(clientSecretKey(origin), clientSecret)

  return { clientId, clientSecret }
}

function generateCodeVerifier(): string {
  const array = new Uint8Array(32)
  crypto.getRandomValues(array)
  return btoa(String.fromCharCode(...array))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}

async function generateCodeChallenge(verifier: string): Promise<string> {
  const encoder = new TextEncoder()
  const data = encoder.encode(verifier)
  const digest = await crypto.subtle.digest('SHA-256', data)
  return btoa(String.fromCharCode(...new Uint8Array(digest)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}

function generateState(): string {
  const array = new Uint8Array(16)
  crypto.getRandomValues(array)
  return Array.from(array, b => b.toString(16).padStart(2, '0')).join('')
}

export async function startMastodonOAuth2(opts: { origin: string }): Promise<Result<void, LoginError>> {
  const normalized = normalizeOrigin(opts.origin)

  try {
    const { clientId } = await ensureApp(normalized)

    const codeVerifier = generateCodeVerifier()
    const codeChallenge = await generateCodeChallenge(codeVerifier)
    const state = generateState()

    storage.set(storage.keyOAuth2CodeVerifier, codeVerifier)
    storage.set(storage.keyOAuth2State, state)
    storage.set(storage.keyOAuth2Origin, normalized)
    storage.set(storage.keyOAuth2Backend, 'mastodon')

    const params = new URLSearchParams({
      client_id: clientId,
      redirect_uri: redirectUri(),
      response_type: 'code',
      scope: SCOPES,
      state,
      code_challenge: codeChallenge,
      code_challenge_method: 'S256',
    })

    window.location.href = `${normalized}/oauth/authorize?${params}`
    return ok(undefined)
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'Mastodon OAuth2 failed'
    return err({ type: 'NetworkError', message: msg })
  }
}

export async function checkMastodonOAuth2(): Promise<Result<void, LoginError>> {
  const codeVerifier = storage.get(storage.keyOAuth2CodeVerifier)
  const expectedState = storage.get(storage.keyOAuth2State)
  const origin = storage.get(storage.keyOAuth2Origin)

  if (!codeVerifier || !expectedState || !origin) {
    return err({ type: 'UnknownError', message: 'Mastodon OAuth2 session data not found' })
  }

  storage.remove(storage.keyOAuth2CodeVerifier)
  storage.remove(storage.keyOAuth2State)
  storage.remove(storage.keyOAuth2Origin)
  storage.remove(storage.keyOAuth2Backend)

  authState.value = 'LoggingIn'

  try {
    const currentUrl = new URL(window.location.href)
    const code = currentUrl.searchParams.get('code')
    const state = currentUrl.searchParams.get('state')

    if (!code) return err({ type: 'UnknownError', message: 'No authorization code in callback' })
    if (state !== expectedState) return err({ type: 'UnknownError', message: 'OAuth2 state mismatch' })

    const clientId = storage.get(clientIdKey(origin))
    const clientSecret = storage.get(clientSecretKey(origin))
    if (!clientId || !clientSecret) {
      return err({ type: 'UnknownError', message: 'Missing client credentials for this instance' })
    }

    const resp = await fetch(`${origin}/oauth/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code,
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri: redirectUri(),
        code_verifier: codeVerifier,
        scope: SCOPES,
      }),
    })

    if (!resp.ok) throw new Error(`Token exchange failed: ${resp.status}`)

    const tokens = await resp.json()
    const accessToken = tokens.access_token as string

    window.history.replaceState(null, '', '/')
    return login({ origin, token: accessToken, backend: 'mastodon' })
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'Token exchange failed'
    authState.value = { type: 'LoginFailed', error: { type: 'NetworkError', message: msg } }
    return err({ type: 'NetworkError', message: msg })
  }
}
