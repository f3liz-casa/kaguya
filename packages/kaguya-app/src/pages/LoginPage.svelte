<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of LoginPage.tsx. Not yet mounted at runtime —
  LoginPage.tsx remains the live page until M5 mount swap.
-->

<script lang="ts">
  import type { PermissionMode } from '../domain/auth/authTypes'
  import { loginErrorMessage } from '../domain/auth/authTypes'
  import { authState, accounts, type Account } from '../domain/auth/appState'
  import { displayLabel } from '../domain/account/account'
  import { removeAccount } from '../domain/account/accountManager'
  import type { BackendType } from '../domain/account/account'
  import * as AuthManager from '../domain/auth/authManager'
  import { connect as misskeyConnect, currentUser as misskeyCurrentUser } from '../lib/misskey'
  import * as Mastodon from '../lib/mastodon'
  import { restoreBlueskySession } from '../domain/auth/blueskyAuth'
  import * as Bluesky from '../lib/bluesky'
  import { currentLocale, t } from '../infra/i18n'
  import { proxyAvatarUrl } from '../infra/mediaProxy'
  import { navigateTo } from 'kaguya-network'
  import { svelteSignal } from '../ui/svelteSignal.svelte'

  type LoginMethod = 'oauth2' | 'miauth' | 'token'
  type BackendChoice = BackendType

  const accountsR = svelteSignal(accounts)
  const authStateR = svelteSignal(authState)
  const localeR = svelteSignal(currentLocale)

  let instanceUrl = $state('')
  let token = $state('')
  let isSubmitting = $state(false)
  let loginMethod = $state<LoginMethod>('oauth2')
  let backendChoice = $state<BackendChoice>('misskey')
  let blueskyHandle = $state('')
  let permissionMode = $state<PermissionMode>('Standard')
  let validAccounts = $state<Account[]>([])
  let invalidAccounts = $state<Account[]>([])
  let isValidating = $state(accounts.peek().length > 0)
  let showAddAccount = $state(false)

  const L = $derived((localeR.value, {
    appTitle: t('app.title'),
    appSubtitle: t('app.subtitle'),
    validating: t('login.validating'),
    accountAdd: t('account.add'),
    invalidTokens: t('account.invalid_tokens'),
    remove: t('action.remove'),
    blueskyHandle: t('login.bluesky_handle'),
    instance: t('login.instance'),
    instancePlaceholder: t('login.instance_placeholder'),
    accessToken: t('login.access_token'),
    permissionMode: t('login.permission_mode'),
    permissionStandard: t('login.permission_standard'),
    permissionReadonly: t('login.permission_readonly'),
    permissionDetailsSummary: t('login.permission_details_summary'),
    permissionStandardDetail: t('login.permission_standard_detail'),
    permissionReadonlyDetail: t('login.permission_readonly_detail'),
    tokenPrivacy: t('login.token_privacy'),
    connecting: t('login.connecting'),
    loginWithBluesky: t('login.login_with_bluesky'),
    loginWithToken: t('login.login_with_token'),
    loginWithMiauth: t('login.login_with_miauth'),
    loginWithOauth2: t('login.login_with_oauth2'),
    helpBluesky: t('login.help_bluesky'),
    helpMastodon: t('login.help_mastodon'),
    helpMiauth: t('login.help_miauth'),
    helpToken: t('login.help_token'),
    helpOauth2: t('login.help_oauth2'),
  }))

  $effect(() => {
    const storedAccounts = accountsR.value
    if (storedAccounts.length === 0) {
      isValidating = false
      return
    }
    isValidating = true
    let cancelled = false
    void (async () => {
      const results = await Promise.all(
        storedAccounts.map(async (account) => {
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
        }),
      )
      if (cancelled) return
      validAccounts = results.filter((r) => r.ok).map((r) => r.account)
      invalidAccounts = results.filter((r) => !r.ok).map((r) => r.account)
      isValidating = false
    })()
    return () => { cancelled = true }
  })

  const errorMessage = $derived.by(() => {
    const s = authStateR.value
    if (typeof s === 'string') return undefined
    if (s.type !== 'LoginFailed') return undefined
    return loginErrorMessage(s.error)
  })

  const isSubmitDisabled = $derived(
    isSubmitting ||
      (backendChoice === 'bluesky' ? !blueskyHandle : !instanceUrl) ||
      (backendChoice !== 'bluesky' && loginMethod === 'token' && !token),
  )

  const effectiveMethod = $derived(backendChoice === 'misskey' ? loginMethod : 'oauth2')

  const submitLabel = $derived(
    backendChoice === 'bluesky'
      ? isSubmitting
        ? L.connecting
        : L.loginWithBluesky
      : effectiveMethod === 'token'
        ? isSubmitting
          ? L.connecting
          : L.loginWithToken
        : effectiveMethod === 'miauth'
          ? L.loginWithMiauth
          : isSubmitting
            ? L.connecting
            : L.loginWithOauth2,
  )

  const helpText = $derived(
    backendChoice === 'bluesky'
      ? L.helpBluesky
      : backendChoice === 'mastodon'
        ? L.helpMastodon
        : effectiveMethod === 'miauth'
          ? L.helpMiauth
          : effectiveMethod === 'token'
            ? L.helpToken
            : L.helpOauth2,
  )

  const hasValidAccounts = $derived(validAccounts.length > 0)

  function handleSubmit(e: Event) {
    e.preventDefault()
    if (backendChoice === 'bluesky') {
      if (!blueskyHandle) return
      isSubmitting = true
      void AuthManager.startBlueskyOAuth2({ handle: blueskyHandle }).then((result) => {
        if (!result.ok) isSubmitting = false
      })
    } else if (!instanceUrl) {
      return
    } else if (backendChoice === 'mastodon') {
      isSubmitting = true
      void AuthManager.startMastodonOAuth2({ origin: instanceUrl }).then((result) => {
        if (!result.ok) isSubmitting = false
      })
    } else if (loginMethod === 'miauth') {
      AuthManager.startMiAuth({ origin: instanceUrl, mode: permissionMode })
    } else if (loginMethod === 'token') {
      if (!token) return
      isSubmitting = true
      void AuthManager.login({ origin: instanceUrl, token }).then(() => {
        isSubmitting = false
      })
    } else {
      isSubmitting = true
      void AuthManager.startOAuth2({ origin: instanceUrl, mode: permissionMode }).then((result) => {
        if (!result.ok) isSubmitting = false
      })
    }
  }

  function handleRevokeAccount(accountId: string) {
    removeAccount(accountId)
    if (accounts.peek().length === 0) {
      authState.value = 'LoggedOut'
    }
  }
</script>

<main class="container login-page">
  <article class="login-card">
    <header>
      <h1 class="login-title">{L.appTitle}</h1>
      <p class="login-subtitle">{L.appSubtitle}</p>
    </header>

    {#if isValidating}
      <div class="login-validating">{L.validating}</div>
    {:else if hasValidAccounts}
      <div class="login-account-switcher">
        {#each validAccounts as account (account.id)}
          <button
            type="button"
            class="login-account-item"
            onclick={() => { void AuthManager.switchAccount(account.id).then((r) => { if (r.ok) navigateTo('/') }) }}
          >
            {#if account.avatarUrl}
              <img class="login-account-avatar" src={proxyAvatarUrl(account.avatarUrl)} alt="" loading="lazy" />
            {:else}
              <div class="login-account-avatar login-account-avatar-placeholder"></div>
            {/if}
            <span class="login-account-label">{displayLabel(account)}</span>
          </button>
        {/each}
        <button
          type="button"
          class="login-account-item login-account-add"
          onclick={() => { showAddAccount = !showAddAccount }}
        >
          <span class="login-account-add-icon">＋</span>
          <span>{L.accountAdd}</span>
        </button>
      </div>
    {/if}

    {#if invalidAccounts.length > 0}
      <div class="login-invalid-accounts">
        <p class="login-invalid-accounts-title">{L.invalidTokens}</p>
        {#each invalidAccounts as account (account.id)}
          <div class="login-invalid-account-item">
            <span>{displayLabel(account)}</span>
            <button
              type="button"
              class="login-invalid-account-remove"
              onclick={() => handleRevokeAccount(account.id)}
            >
              {L.remove}
            </button>
          </div>
        {/each}
      </div>
    {/if}

    {#if !isValidating && (!hasValidAccounts || showAddAccount)}
      <form onsubmit={handleSubmit}>
        <div class="login-method-tabs">
          <button
            class={backendChoice === 'misskey' ? 'active' : ''}
            onclick={() => { backendChoice = 'misskey' }}
            type="button"
          >Misskey</button>
          <button
            class={backendChoice === 'mastodon' ? 'active' : ''}
            onclick={() => { backendChoice = 'mastodon' }}
            type="button"
          >Mastodon</button>
          <button
            class={backendChoice === 'bluesky' ? 'active' : ''}
            onclick={() => { backendChoice = 'bluesky' }}
            type="button"
          >Bluesky</button>
        </div>

        {#if backendChoice === 'bluesky'}
          <label for="bluesky-handle">
            {L.blueskyHandle}
            <input
              type="text"
              id="bluesky-handle"
              name="bluesky-handle"
              placeholder="alice.bsky.social"
              value={blueskyHandle}
              oninput={(e) => { blueskyHandle = (e.currentTarget as HTMLInputElement).value }}
              disabled={isSubmitting}
              autofocus
              required
            />
          </label>
        {:else}
          <label for="instance">
            {L.instance}
            <input
              type="text"
              id="instance"
              name="instance"
              placeholder={backendChoice === 'mastodon' ? 'mastodon.social' : L.instancePlaceholder}
              value={instanceUrl}
              oninput={(e) => { instanceUrl = (e.currentTarget as HTMLInputElement).value }}
              disabled={isSubmitting}
              autofocus
              required
            />
          </label>
        {/if}

        {#if backendChoice === 'misskey'}
          <div class="login-method-tabs">
            <button
              class={loginMethod === 'oauth2' ? 'active' : ''}
              onclick={() => { loginMethod = 'oauth2' }}
              type="button"
            >OAuth2</button>
            <button
              class={loginMethod === 'miauth' ? 'active' : ''}
              onclick={() => { loginMethod = 'miauth' }}
              type="button"
            >MiAuth</button>
            <button
              class={loginMethod === 'token' ? 'active' : ''}
              onclick={() => { loginMethod = 'token' }}
              type="button"
            >{L.accessToken}</button>
          </div>
        {/if}

        {#if backendChoice === 'misskey' && loginMethod === 'token'}
          <label for="token">
            {L.accessToken}
            <input
              type="password"
              id="token"
              name="token"
              placeholder={L.accessToken}
              value={token}
              oninput={(e) => { token = (e.currentTarget as HTMLInputElement).value }}
              disabled={isSubmitting}
              required
            />
          </label>
        {:else if backendChoice === 'misskey'}
          <label for="permission-mode">
            {L.permissionMode}
            <select
              id="permission-mode"
              name="permission-mode"
              value={permissionMode === 'ReadOnly' ? 'readonly' : 'standard'}
              onchange={(e) => { permissionMode = (e.currentTarget as HTMLSelectElement).value === 'readonly' ? 'ReadOnly' : 'Standard' }}
            >
              <option value="standard">{L.permissionStandard}</option>
              <option value="readonly">{L.permissionReadonly}</option>
            </select>
            <details class="login-permission-details">
              <summary>{L.permissionDetailsSummary}</summary>
              <p>{L.permissionStandardDetail}</p>
              <p>{L.permissionReadonlyDetail}</p>
            </details>
          </label>
        {/if}

        {#if errorMessage}
          <div class="error-message" role="alert">
            <p>{errorMessage}</p>
          </div>
        {/if}

        <button type="submit" disabled={isSubmitDisabled}>{submitLabel}</button>
        <small class="login-help">{helpText}</small>
        <small class="login-privacy-note">
          <iconify-icon icon="tabler:lock"></iconify-icon>
          {L.tokenPrivacy}
        </small>
      </form>
    {/if}
  </article>
</main>
