// SPDX-License-Identifier: MPL-2.0

import { useState, useEffect } from 'preact/hooks'
import { checkOAuth2, checkMastodonOAuth2, checkBlueskyOAuth2 } from '../domain/auth/authManager'
import * as storage from '../infra/storage'
import { loginErrorMessage } from '../domain/auth/authTypes'
import { navigateTo, getSearchParam } from 'kaguya-network'
import { t } from '../infra/i18n'

type Status = 'checking' | 'success' | 'error'

export function OAuthCallbackPage() {
  const [status, setStatus] = useState<Status>('checking')
  const [errorMessage, setErrorMessage] = useState<string | undefined>()

  useEffect(() => {
    let isMounted = true

    void (async () => {
      try {
        if (!isMounted) return
        const errorParam = getSearchParam('error')

        if (errorParam) {
          console.error('OAuthCallbackPage: Authorization error:', errorParam)
          if (isMounted) { setStatus('error'); setErrorMessage(errorParam) }
          return
        }

        const pendingBackend = storage.get(storage.keyOAuth2Backend)
        const result = pendingBackend === 'bluesky'
          ? await checkBlueskyOAuth2()
          : pendingBackend === 'mastodon'
            ? await checkMastodonOAuth2()
            : await checkOAuth2()
        if (result.ok) {
          if (isMounted) setStatus('success')
          navigateTo('/')
        } else {
          const msg = loginErrorMessage(result.error)
          if (isMounted) { setStatus('error'); setErrorMessage(msg) }
        }
      } catch (e) {
        console.error('OAuthCallbackPage: Exception', e)
        if (isMounted) {
          setStatus('error')
          setErrorMessage(e instanceof Error ? e.message : t('error.unknown'))
        }
      }
    })()

    return () => { isMounted = false }
  }, [])

  return (
    <main class="container login-page">
      <article class="login-card">
        <header>
          <h1 class="login-title">{t('app.title')}</h1>
        </header>
        {status === 'checking' ? (
          <div class="loading-container"><p>{t('auth.checking')}</p></div>
        ) : status === 'success' ? (
          <div class="success-message">
            <div style={{ fontSize: '2rem', marginBottom: '0.5rem' }}>✓</div>
            <p>{t('auth.login_success')}</p>
            <p class="auth-redirect-hint">
              {t('auth.redirecting_home')}
            </p>
          </div>
        ) : status === 'error' ? (
          <div class="error-message">
            <p>{t('auth.failed')}</p>
            {errorMessage && (
              <details style={{ marginTop: '0.5rem' }}>
                <summary class="auth-error-details-summary">
                  {t('auth.error_details')}
                </summary>
                <pre class="auth-error-pre">
                  {errorMessage}
                </pre>
              </details>
            )}
            <p class="auth-error-back">
              <a href="/">{t('auth.back_to_login')}</a>
            </p>
          </div>
        ) : null}
      </article>
    </main>
  )
}
