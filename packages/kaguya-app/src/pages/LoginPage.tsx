// SPDX-License-Identifier: MPL-2.0

import { useState, useEffect } from 'preact/hooks'
import type { PermissionMode } from '../domain/auth/authTypes'
import { loginErrorMessage } from '../domain/auth/authTypes'
import { authState, accounts } from '../domain/auth/appState'
import { displayLabel } from '../domain/account/account'
import { removeAccount } from '../domain/account/accountManager'
import type { BackendType } from '../domain/account/account'
import * as AuthManager from '../domain/auth/authManager'
import { connect as misskeyConnect, currentUser as misskeyCurrentUser } from '../lib/misskey'
import * as Mastodon from '../lib/mastodon'
import { restoreBlueskySession } from '../domain/auth/blueskyAuth'
import * as Bluesky from '../lib/bluesky'
import { t } from '../infra/i18n'
import { proxyAvatarUrl } from '../infra/mediaProxy'
import { navigateTo } from 'kaguya-network'

type LoginMethod = 'oauth2' | 'miauth' | 'token'
type BackendChoice = BackendType

export function LoginPage() {
  const [instanceUrl, setInstanceUrl] = useState('')
  const [token, setToken] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [loginMethod, setLoginMethod] = useState<LoginMethod>('oauth2')
  const [backendChoice, setBackendChoice] = useState<BackendChoice>('misskey')
  const [blueskyHandle, setBlueskyHandle] = useState('')
  const [permissionMode, setPermissionMode] = useState<PermissionMode>('Standard')
  const [validAccounts, setValidAccounts] = useState<typeof accounts.value>([])
  const [invalidAccounts, setInvalidAccounts] = useState<typeof accounts.value>([])
  const [isValidating, setIsValidating] = useState(() => accounts.value.length > 0)
  const [showAddAccount, setShowAddAccount] = useState(false)

  const storedAccounts = accounts.value
  const currentAuthState = authState.value

  useEffect(() => {
    if (storedAccounts.length === 0) {
      setIsValidating(false)
      return
    }
    setIsValidating(true)
    void (async () => {
      const results = await Promise.all(
        storedAccounts.map(async account => {
          if (account.backend === 'bluesky' && account.blueskyDid) {
            try {
              const session = await restoreBlueskySession(account.blueskyDid)
              if (!session) return { account, ok: false }
              const bskyClient = Bluesky.connectFromSession(session)
              const result = await Bluesky.Accounts.getProfile(bskyClient)
              return { account, ok: result.ok }
            } catch {
              return { account, ok: false }
            }
          }
          if (account.backend === 'mastodon') {
            const c = Mastodon.connect(account.origin, account.token)
            const result = await Mastodon.Accounts.verifyCredentials(c)
            return { account, ok: result.ok }
          }
          const c = misskeyConnect(account.origin, account.token)
          const result = await misskeyCurrentUser(c)
          return { account, ok: result.ok }
        })
      )
      setValidAccounts(results.filter(r => r.ok).map(r => r.account))
      setInvalidAccounts(results.filter(r => !r.ok).map(r => r.account))
      setIsValidating(false)
    })()
  }, [storedAccounts])

  const errorMessage = (() => {
    if (typeof currentAuthState === 'string') return undefined
    if (currentAuthState.type !== 'LoginFailed') return undefined
    return loginErrorMessage(currentAuthState.error)
  })()

  const isSubmitDisabled = isSubmitting
    || (backendChoice === 'bluesky' ? !blueskyHandle : !instanceUrl)
    || (backendChoice !== 'bluesky' && loginMethod === 'token' && !token)

  const effectiveMethod = backendChoice === 'misskey' ? loginMethod : 'oauth2'

  const submitLabel = backendChoice === 'bluesky'
    ? (isSubmitting ? t('login.connecting') : t('login.login_with_bluesky'))
    : effectiveMethod === 'token'
      ? (isSubmitting ? t('login.connecting') : t('login.login_with_token'))
      : effectiveMethod === 'miauth'
        ? t('login.login_with_miauth')
        : (isSubmitting ? t('login.connecting') : t('login.login_with_oauth2'))

  const helpText = backendChoice === 'bluesky'
    ? t('login.help_bluesky')
    : backendChoice === 'mastodon'
      ? t('login.help_mastodon')
      : effectiveMethod === 'miauth'
        ? t('login.help_miauth')
        : effectiveMethod === 'token'
          ? t('login.help_token')
          : t('login.help_oauth2')

  function handleSubmit(e: Event) {
    e.preventDefault()
    if (backendChoice === 'bluesky') {
      if (!blueskyHandle) return
      setIsSubmitting(true)
      void AuthManager.startBlueskyOAuth2({ handle: blueskyHandle })
        .then(result => { if (!result.ok) setIsSubmitting(false) })
    } else if (!instanceUrl) {
      return
    } else if (backendChoice === 'mastodon') {
      setIsSubmitting(true)
      void AuthManager.startMastodonOAuth2({ origin: instanceUrl })
        .then(result => { if (!result.ok) setIsSubmitting(false) })
    } else if (loginMethod === 'miauth') {
      AuthManager.startMiAuth({ origin: instanceUrl, mode: permissionMode })
    } else if (loginMethod === 'token') {
      if (!token) return
      setIsSubmitting(true)
      void AuthManager.login({ origin: instanceUrl, token }).then(() => setIsSubmitting(false))
    } else {
      setIsSubmitting(true)
      void AuthManager.startOAuth2({ origin: instanceUrl, mode: permissionMode })
        .then(result => { if (!result.ok) setIsSubmitting(false) })
    }
  }

  function handleRevokeAccount(accountId: string) {
    removeAccount(accountId)
    if (accounts.value.length === 0) {
      authState.value = 'LoggedOut'
    }
  }

  const hasValidAccounts = validAccounts.length > 0

  return (
    <main class="container login-page">
      <article class="login-card">
        <header>
          <h1 class="login-title">{t('app.title')}</h1>
          <p class="login-subtitle">{t('app.subtitle')}</p>
        </header>

        {isValidating ? (
          <div class="login-validating">{t('login.validating')}</div>
        ) : hasValidAccounts ? (
          <div class="login-account-switcher">
            {validAccounts.map(account => (
              <button
                key={account.id}
                type="button"
                class="login-account-item"
                onClick={() => { void AuthManager.switchAccount(account.id).then(r => { if (r.ok) navigateTo('/') }) }}
              >
                {account.avatarUrl
                  ? <img class="login-account-avatar" src={proxyAvatarUrl(account.avatarUrl)} alt="" loading="lazy" />
                  : <div class="login-account-avatar login-account-avatar-placeholder" />
                }
                <span class="login-account-label">{displayLabel(account)}</span>
              </button>
            ))}
            <button
              type="button"
              class="login-account-item login-account-add"
              onClick={() => setShowAddAccount(v => !v)}
            >
              <span class="login-account-add-icon">＋</span>
              <span>{t('account.add')}</span>
            </button>
          </div>
        ) : null}

        {invalidAccounts.length > 0 && (
          <div class="login-invalid-accounts">
            <p class="login-invalid-accounts-title">{t('account.invalid_tokens')}</p>
            {invalidAccounts.map(account => (
              <div key={account.id} class="login-invalid-account-item">
                <span>{displayLabel(account)}</span>
                <button
                  type="button"
                  class="login-invalid-account-remove"
                  onClick={() => handleRevokeAccount(account.id)}
                >
                  {t('action.remove')}
                </button>
              </div>
            ))}
          </div>
        )}

        {!isValidating && (!hasValidAccounts || showAddAccount) && (
          <form onSubmit={handleSubmit}>
            <div class="login-method-tabs">
              <button class={backendChoice === 'misskey' ? 'active' : ''} onClick={() => setBackendChoice('misskey')} type="button">Misskey</button>
              <button class={backendChoice === 'mastodon' ? 'active' : ''} onClick={() => setBackendChoice('mastodon')} type="button">Mastodon</button>
              <button class={backendChoice === 'bluesky' ? 'active' : ''} onClick={() => setBackendChoice('bluesky')} type="button">Bluesky</button>
            </div>

            {backendChoice === 'bluesky' ? (
              <label for="bluesky-handle">
                {t('login.bluesky_handle')}
                <input
                  type="text"
                  id="bluesky-handle"
                  name="bluesky-handle"
                  placeholder="alice.bsky.social"
                  value={blueskyHandle}
                  onInput={e => setBlueskyHandle((e.target as HTMLInputElement).value)}
                  disabled={isSubmitting}
                  autoFocus
                  required
                />
              </label>
            ) : (
              <label for="instance">
                {t('login.instance')}
                <input
                  type="text"
                  id="instance"
                  name="instance"
                  placeholder={backendChoice === 'mastodon' ? 'mastodon.social' : t('login.instance_placeholder')}
                  value={instanceUrl}
                  onInput={e => setInstanceUrl((e.target as HTMLInputElement).value)}
                  disabled={isSubmitting}
                  autoFocus
                  required
                />
              </label>
            )}

            {backendChoice === 'misskey' && (
              <div class="login-method-tabs">
                <button class={loginMethod === 'oauth2' ? 'active' : ''} onClick={() => setLoginMethod('oauth2')} type="button">OAuth2</button>
                <button class={loginMethod === 'miauth' ? 'active' : ''} onClick={() => setLoginMethod('miauth')} type="button">MiAuth</button>
                <button class={loginMethod === 'token' ? 'active' : ''} onClick={() => setLoginMethod('token')} type="button">{t('login.access_token')}</button>
              </div>
            )}

            {backendChoice === 'misskey' && loginMethod === 'token' ? (
              <label for="token">
                {t('login.access_token')}
                <input
                  type="password"
                  id="token"
                  name="token"
                  placeholder={t('login.access_token')}
                  value={token}
                  onInput={e => setToken((e.target as HTMLInputElement).value)}
                  disabled={isSubmitting}
                  required
                />
              </label>
            ) : backendChoice === 'misskey' ? (
              <label for="permission-mode">
                {t('login.permission_mode')}
                <select
                  id="permission-mode"
                  name="permission-mode"
                  value={permissionMode === 'ReadOnly' ? 'readonly' : 'standard'}
                  onChange={e => setPermissionMode((e.target as HTMLSelectElement).value === 'readonly' ? 'ReadOnly' : 'Standard')}
                >
                  <option value="standard">{t('login.permission_standard')}</option>
                  <option value="readonly">{t('login.permission_readonly')}</option>
                </select>
                <details class="login-permission-details">
                  <summary>{t('login.permission_details_summary')}</summary>
                  <p>{t('login.permission_standard_detail')}</p>
                  <p>{t('login.permission_readonly_detail')}</p>
                </details>
              </label>
            ) : null}

            {errorMessage && (
              <div class="error-message" role="alert">
                <p>{errorMessage}</p>
              </div>
            )}

            <button type="submit" disabled={isSubmitDisabled}>{submitLabel}</button>
            <small class="login-help">{helpText}</small>
            <small class="login-privacy-note">
              <iconify-icon icon="tabler:lock" />
              {t('login.token_privacy')}
            </small>
          </form>
        )}
      </article>
    </main>
  )
}
