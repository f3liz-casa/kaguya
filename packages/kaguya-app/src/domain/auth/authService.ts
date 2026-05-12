// SPDX-License-Identifier: MPL-2.0

import { batch } from '@preact/signals-core'
import type { LoginError } from './authTypes'
import {
  instanceOrigin, accessToken, authState, client, currentUser,
  permissionMode, accounts, activeAccountId, isSwitchingAccount,
} from './appState'
import { upsertAccount, removeAccount, getActiveAccount } from '../account/accountManager'
import { makeId as makeAccountId, permissionModeToString } from '../account/account'
import type { Account } from '../account/account'
import { subscribe as notifSubscribe, unsubscribe as notifUnsubscribe, clear as notifClear, setInitial as notifSetInitial } from '../notification/notificationStore'
import { restore as pushRestore, unsubscribe as pushUnsubscribe } from '../notification/pushNotificationStore'
import { clear as timelineClear, setFromInitData } from '../timeline/timelineStore'
import { clear as emojiClear } from '../emoji/emojiStore'
import * as storage from '../../infra/storage'
import { normalizeOrigin, hostnameFromOrigin } from '../../infra/urlUtils'
import { asObj, getString } from '../../infra/jsonUtils'
import { addPreconnectForInstance, prefetchCommonDomains } from '../../infra/networkOptimizer'
import * as Misskey from '../../lib/misskey'
import * as Mastodon from '../../lib/mastodon'
import * as Bluesky from '../../lib/bluesky'
import * as Backend from '../../lib/backend'
import type { BackendClient } from '../../lib/backend'
import type { BackendType } from '../account/account'
import type { OAuthSession } from '@atproto/oauth-client-browser'
import type { Result } from '../../infra/result'
import { ok, err } from '../../infra/result'

function finalizeLogin(bc: BackendClient, accountId: string, origin: string): void {
  if (bc.backend === 'misskey') {
    notifSubscribe(bc.client)
    void pushRestore(bc, accountId)
  }
  addPreconnectForInstance(origin)
  prefetchCommonDomains(origin)
}

export async function login(opts: { origin: string; token: string; backend?: BackendType }): Promise<Result<void, LoginError>> {
  const normalized = normalizeOrigin(opts.origin)
  const backendType = opts.backend ?? 'misskey'
  authState.value = 'LoggingIn'

  try {
    let bc: BackendClient
    let userJson: unknown
    let userUsername: string
    let userAvatarUrl: string
    let backendUserId: string

    if (backendType === 'mastodon') {
      const mastoClient = Mastodon.connect(normalized, opts.token)
      bc = { backend: 'mastodon', client: mastoClient }
      const userResult = await Mastodon.Accounts.verifyCredentials(mastoClient)
      if (!userResult.ok) {
        authState.value = { type: 'LoginFailed', error: { type: 'InvalidCredentials' } }
        return err({ type: 'InvalidCredentials' })
      }
      userJson = userResult.value
      const userObj = userResult.value
      userUsername = userObj.username ?? 'unknown'
      userAvatarUrl = userObj.avatar ?? ''
      backendUserId = userObj.id ?? ''
    } else {
      const misskeyClient = Misskey.connect(normalized, opts.token)
      bc = { backend: 'misskey', client: misskeyClient }
      const userResult = await Misskey.currentUser(misskeyClient)
      if (!userResult.ok) {
        authState.value = { type: 'LoginFailed', error: { type: 'InvalidCredentials' } }
        return err({ type: 'InvalidCredentials' })
      }
      userJson = userResult.value
      const userObj = asObj(userJson)
      userUsername = getString(userObj ?? {}, 'username') ?? 'unknown'
      userAvatarUrl = getString(userObj ?? {}, 'avatarUrl') ?? ''
      backendUserId = getString(userObj ?? {}, 'id') ?? ''
    }

    const userHost = hostnameFromOrigin(normalized)

    storage.set(storage.keyOrigin, normalized)
    storage.set(storage.keyToken, opts.token)

    const permMode = storage.get(storage.keyPermissionMode) === 'ReadOnly' ? 'ReadOnly' as const : 'Standard' as const

    const accountId = makeAccountId(normalized, userUsername)
    const account: Account = {
      id: accountId,
      origin: normalized,
      token: opts.token,
      username: userUsername,
      host: userHost,
      avatarUrl: userAvatarUrl,
      permissionMode: permMode,
      backend: backendType,
      misskeyUserId: backendType === 'misskey' ? backendUserId : '',
      mastodonAccountId: backendType === 'mastodon' ? backendUserId : '',
      blueskyDid: '',
    }

    upsertAccount(account)
    storage.set(storage.keyActiveAccountId, accountId)

    batch(() => {
      instanceOrigin.value = normalized
      accessToken.value = opts.token
      client.value = bc
      currentUser.value = userJson
      permissionMode.value = permMode
      activeAccountId.value = accountId
      authState.value = 'LoggedIn'
    })

    if (backendType === 'misskey' && bc.backend === 'misskey') {
      void fetchSupplementaryData(bc.client, accountId, normalized)
    } else {
      finalizeLogin(bc, accountId, normalized)
    }

    return ok(undefined)
  } catch {
    const error: LoginError = { type: 'NetworkError', message: 'Network error during login' }
    authState.value = { type: 'LoginFailed', error }
    return err(error)
  }
}

export async function loginBluesky(opts: { session: OAuthSession }): Promise<Result<void, LoginError>> {
  authState.value = 'LoggingIn'

  try {
    const bskyClient = Bluesky.connectFromSession(opts.session)
    const bc: BackendClient = { backend: 'bluesky', client: bskyClient }

    const userResult = await Bluesky.Accounts.getProfile(bskyClient)
    if (!userResult.ok) {
      console.error('Bluesky getProfile failed:', userResult.error)
      authState.value = { type: 'LoginFailed', error: { type: 'NetworkError', message: `Bluesky login failed: ${userResult.error}` } }
      return err({ type: 'NetworkError', message: `Bluesky login failed: ${userResult.error}` })
    }
    const userJson = userResult.value
    const userObj = asObj(userJson)
    const userHandle = getString(userObj ?? {}, 'handle') ?? 'unknown'
    const userAvatarUrl = getString(userObj ?? {}, 'avatar') ?? ''
    const userDid = opts.session.did

    // Update client handle now that we have it
    bskyClient.handle = userHandle

    const origin = 'https://bsky.social'
    const userHost = 'bsky.social'

    storage.set(storage.keyOrigin, origin)
    storage.set(storage.keyToken, userDid) // Store DID as token for session restoration

    const accountId = makeAccountId(origin, userHandle)
    const account: Account = {
      id: accountId,
      origin,
      token: userDid,
      username: userHandle,
      host: userHost,
      avatarUrl: userAvatarUrl,
      permissionMode: 'Standard',
      backend: 'bluesky',
      misskeyUserId: '',
      mastodonAccountId: '',
      blueskyDid: userDid,
    }

    upsertAccount(account)
    storage.set(storage.keyActiveAccountId, accountId)

    batch(() => {
      instanceOrigin.value = origin
      accessToken.value = userDid
      client.value = bc
      currentUser.value = userJson
      permissionMode.value = 'Standard'
      activeAccountId.value = accountId
      authState.value = 'LoggedIn'
    })

    void fetchSupplementaryDataBluesky(bc, accountId, origin)
    return ok(undefined)
  } catch (e) {
    console.error('Bluesky loginBluesky error:', e)
    const msg = e instanceof Error ? e.message : 'Network error during Bluesky login'
    const error: LoginError = { type: 'NetworkError', message: msg }
    authState.value = { type: 'LoginFailed', error }
    return err(error)
  }
}

async function fetchSupplementaryDataBluesky(
  bc: BackendClient,
  accountId: string,
  origin: string,
): Promise<void> {
  try {
    const [listsResult, feedsResult] = await Promise.all([
      Backend.listLists(bc),
      Backend.listFeeds(bc),
    ])
    setFromInitData({
      antennasResult: ok([]),
      listsResult,
      channelsResult: ok([]),
      feedsResult,
    })
  } catch {
    console.error('Failed to fetch Bluesky supplementary data')
  }

  finalizeLogin(bc, accountId, origin)
}

async function fetchSupplementaryData(
  newClient: Misskey.MisskeyClient,
  accountId: string,
  normalized: string,
): Promise<void> {
  try {
    const [notificationsResult, antennasResult, listsResult, channelsResult, homeTimelineResult] = await Promise.all([
      Misskey.request(newClient, 'i/notifications', { limit: 30 }),
      Misskey.CustomTimelines.antennas(newClient),
      Misskey.CustomTimelines.lists(newClient),
      Misskey.CustomTimelines.channels(newClient),
      Misskey.Notes.fetch(newClient, 'home', 20),
    ])

    notifSetInitial(notificationsResult)
    setFromInitData({
      antennasResult,
      listsResult,
      channelsResult,
      homeTimelineResult,
    })
  } catch {
    console.error('Failed to fetch supplementary data')
  }

  finalizeLogin({ backend: 'misskey', client: newClient }, accountId, normalized)
}

function teardownStores(): void {
  notifUnsubscribe()
  notifClear()
  timelineClear()
  emojiClear()
}

export function logout(): void {
  const currentId = activeAccountId.value
  if (currentId) removeAccount(currentId)

  storage.remove(storage.keyOrigin)
  storage.remove(storage.keyToken)
  storage.remove(storage.keyPermissionMode)
  storage.remove(storage.keyActiveAccountId)
  storage.remove(storage.keyMiAuthSession)
  storage.remove(storage.keyMiAuthOrigin)

  const currentClient = client.value
  if (currentClient) {
    Backend.close(currentClient)
    if (currentId) {
      void pushUnsubscribe(currentClient, currentId)
    }
  }

  teardownStores()

  batch(() => {
    instanceOrigin.value = undefined
    accessToken.value = undefined
    client.value = undefined
    currentUser.value = undefined
    permissionMode.value = undefined
    activeAccountId.value = undefined
    authState.value = 'LoggedOut'
  })
}

export async function switchAccount(accountId: string): Promise<Result<void, LoginError>> {
  const accs = accounts.value
  const account = accs.find(a => a.id === accountId)
  if (!account) return err({ type: 'UnknownError', message: 'Account not found' })

  isSwitchingAccount.value = true

  const currentClient = client.value
  if (currentClient) Backend.close(currentClient)
  teardownStores()

  storage.set(storage.keyActiveAccountId, accountId)
  storage.set(storage.keyPermissionMode, permissionModeToString(account.permissionMode))

  let result: Result<void, LoginError>
  if (account.backend === 'bluesky' && account.blueskyDid) {
    const { restoreBlueskySession } = await import('./blueskyAuth')
    const session = await restoreBlueskySession(account.blueskyDid)
    if (session) {
      result = await loginBluesky({ session })
    } else {
      result = err({ type: 'InvalidCredentials' })
    }
  } else {
    result = await login({ origin: account.origin, token: account.token, backend: account.backend })
  }
  isSwitchingAccount.value = false
  return result
}

export async function restoreSession(): Promise<void> {
  const storedAccounts = accounts.value

  if (storedAccounts.length > 0) {
    const active = getActiveAccount()
    if (active) {
      if (active.backend === 'bluesky' && active.blueskyDid) {
        const { restoreBlueskySession } = await import('./blueskyAuth')
        const session = await restoreBlueskySession(active.blueskyDid)
        if (session) {
          await loginBluesky({ session })
          return
        }
      } else {
        await login({ origin: active.origin, token: active.token, backend: active.backend })
        return
      }
    }
  } else {
    const origin = storage.get(storage.keyOrigin)
    const token = storage.get(storage.keyToken)
    if (origin && token) {
      await login({ origin, token })
      return
    }
  }

  // No valid credentials found — ensure we don't stay stuck in 'LoggingIn'
  authState.value = 'LoggedOut'
}
