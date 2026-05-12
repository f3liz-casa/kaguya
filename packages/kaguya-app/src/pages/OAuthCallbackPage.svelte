<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of OAuthCallbackPage.tsx. Not yet mounted at runtime —
  OAuthCallbackPage.tsx remains the live page until M5 mount swap.
-->

<script lang="ts">
  import { onMount } from 'svelte'
  import { checkOAuth2, checkMastodonOAuth2, checkBlueskyOAuth2 } from '../domain/auth/authManager'
  import * as storage from '../infra/storage'
  import { loginErrorMessage } from '../domain/auth/authTypes'
  import { navigateTo, getSearchParam } from 'kaguya-network'
  import { currentLocale, t } from '../infra/i18n'
  import { svelteSignal } from '../ui/svelteSignal.svelte'

  type Status = 'checking' | 'success' | 'error'

  const localeR = svelteSignal(currentLocale)
  let status = $state<Status>('checking')
  let errorMessage = $state<string | undefined>(undefined)

  const L = $derived((localeR.value, {
    appTitle: t('app.title'),
    checking: t('auth.checking'),
    loginSuccess: t('auth.login_success'),
    redirectingHome: t('auth.redirecting_home'),
    failed: t('auth.failed'),
    errorDetails: t('auth.error_details'),
    backToLogin: t('auth.back_to_login'),
    unknown: t('error.unknown'),
  }))

  onMount(() => {
    let isMounted = true

    void (async () => {
      try {
        if (!isMounted) return
        const errorParam = getSearchParam('error')

        if (errorParam) {
          console.error('OAuthCallbackPage: Authorization error:', errorParam)
          if (isMounted) { status = 'error'; errorMessage = errorParam }
          return
        }

        const pendingBackend = storage.get(storage.keyOAuth2Backend)
        const result = pendingBackend === 'bluesky'
          ? await checkBlueskyOAuth2()
          : pendingBackend === 'mastodon'
            ? await checkMastodonOAuth2()
            : await checkOAuth2()
        if (result.ok) {
          if (isMounted) status = 'success'
          navigateTo('/')
        } else {
          const msg = loginErrorMessage(result.error)
          if (isMounted) { status = 'error'; errorMessage = msg }
        }
      } catch (e) {
        console.error('OAuthCallbackPage: Exception', e)
        if (isMounted) {
          status = 'error'
          errorMessage = e instanceof Error ? e.message : L.unknown
        }
      }
    })()

    return () => { isMounted = false }
  })
</script>

<main class="container login-page">
  <article class="login-card">
    <header>
      <h1 class="login-title">{L.appTitle}</h1>
    </header>
    {#if status === 'checking'}
      <div class="loading-container"><p>{L.checking}</p></div>
    {:else if status === 'success'}
      <div class="success-message">
        <div style="font-size: 2rem; margin-bottom: 0.5rem">✓</div>
        <p>{L.loginSuccess}</p>
        <p class="auth-redirect-hint">{L.redirectingHome}</p>
      </div>
    {:else}
      <div class="error-message">
        <p>{L.failed}</p>
        {#if errorMessage}
          <details style="margin-top: 0.5rem">
            <summary class="auth-error-details-summary">{L.errorDetails}</summary>
            <pre class="auth-error-pre">{errorMessage}</pre>
          </details>
        {/if}
        <p class="auth-error-back">
          <a href="/">{L.backToLogin}</a>
        </p>
      </div>
    {/if}
  </article>
</main>
