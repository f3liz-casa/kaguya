<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of MiAuthCallbackPage.tsx. Not yet mounted at runtime —
  MiAuthCallbackPage.tsx remains the live page until M5 mount swap.

  Note: original .tsx hard-codes a few Japanese strings (login banner,
  "認証確認中…", "ログイン成功！", "ホームへ移動中…", "セッション期限
  切れ…") rather than routing them through t(). Faithful port keeps
  them as-is; i18n key extraction is queued for M5 PR-b audit cleanup,
  not part of this move.
-->

<script lang="ts">
  import { authState } from '../domain/auth/appState'
  import { checkMiAuth } from '../domain/auth/authManager'
  import { loginErrorMessage } from '../domain/auth/authTypes'
  import { navigateTo } from 'kaguya-network'
  import { currentLocale, t } from '../infra/i18n'
  import { svelteSignal } from '../ui/svelteSignal.svelte'

  type Status = 'checking' | 'success' | 'permanent_error' | 'error'

  const MAX_RETRIES = 10

  const localeR = svelteSignal(currentLocale)
  let status = $state<Status>('checking')
  let errorMessage = $state<string | undefined>(undefined)
  let retryCount = $state(0)

  const L = $derived((localeR.value, {
    errorDetails: t('auth.error_details'),
    backToLogin: t('auth.back_to_login'),
    failed: t('auth.failed'),
    unknown: t('error.unknown'),
    loggingIn: t('auth.logging_in'),
    checking: t('auth.checking'),
    loginSuccess: t('auth.login_success'),
    redirectingHome: t('auth.redirecting_home'),
    sessionExpired: t('auth.session_expired'),
  }))

  $effect(() => {
    // retryCount in $effect's dep set drives the exp-backoff retry,
    // mirroring useEffect[retryCount] semantics from the Preact version.
    const _depTrigger = retryCount
    let isMounted = true

    void (async () => {
      try {
        if (!isMounted) return
        const result = await checkMiAuth()

        if (result.ok) {
          if (isMounted) status = 'success'
          navigateTo('/')
        } else {
          const err = result.error
          const errorMsg = loginErrorMessage(err)
          const isPermanent = err.type === 'SessionExpired'

          if (isPermanent) {
            if (isMounted) { status = 'permanent_error'; errorMessage = errorMsg }
            authState.value = { type: 'LoginFailed', error: err }
          } else if (_depTrigger < MAX_RETRIES) {
            const rawDelay = 1000 * Math.pow(2, _depTrigger)
            const delay = Math.min(rawDelay, 16000)
            if (isMounted) {
              status = 'checking'
              setTimeout(() => { if (isMounted) retryCount = retryCount + 1 }, delay)
            }
          } else if (isMounted) {
            status = 'error'
            errorMessage = errorMsg
          }
        }
      } catch (e) {
        console.error('MiAuthCallbackPage: Exception', e)
        if (isMounted) {
          status = 'error'
          errorMessage = e instanceof Error ? e.message : L.unknown
        }
      }
    })()

    return () => { isMounted = false }
  })
</script>

<main class="container">
  <article class="login-card">
    <header><h1>{L.loggingIn}</h1></header>
    {#if status === 'checking'}
      <div class="loading-container"><p>{L.checking}</p></div>
    {:else if status === 'success'}
      <div class="success-message">
        <div style="font-size: 2rem; margin-bottom: 0.5rem">✓</div>
        <p>{L.loginSuccess}</p>
        <p style="font-size: 0.875rem; font-weight: 400; margin-top: 0.5rem; color: #158033">
          {L.redirectingHome}
        </p>
      </div>
    {:else if status === 'permanent_error'}
      <div class="error-message">
        <p>{L.sessionExpired}</p>
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
    {:else if status === 'error'}
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
