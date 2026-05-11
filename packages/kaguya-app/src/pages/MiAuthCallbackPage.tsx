// SPDX-License-Identifier: MPL-2.0

import { useState, useEffect } from 'preact/hooks'
import { authState } from '../domain/auth/appState'
import { checkMiAuth } from '../domain/auth/authManager'
import { loginErrorMessage } from '../domain/auth/authTypes'
import { navigateTo } from 'kaguya-network'
import { t } from '../infra/i18n'

type Status = 'checking' | 'success' | 'permanent_error' | 'error'

const MAX_RETRIES = 10

export function MiAuthCallbackPage() {
  const [status, setStatus] = useState<Status>('checking')
  const [errorMessage, setErrorMessage] = useState<string | undefined>()
  const [retryCount, setRetryCount] = useState(0)

  useEffect(() => {
    let isMounted = true

    void (async () => {
      try {
        if (!isMounted) return
        const result = await checkMiAuth()

        if (result.ok) {
          if (isMounted) setStatus('success')
          navigateTo('/')
        } else {
          const err = result.error
          const errorMsg = loginErrorMessage(err)

          const isPermanent = errorMsg.includes('Session information not found') || errorMsg.includes('セッション')

          if (isPermanent) {
            if (isMounted) { setStatus('permanent_error'); setErrorMessage(errorMsg) }
            authState.value = { type: 'LoginFailed', error: err }
          } else if (retryCount < MAX_RETRIES) {
            const rawDelay = 1000 * Math.pow(2, retryCount)
            const delay = Math.min(rawDelay, 16000)
            if (isMounted) {
              setStatus('checking')
              setTimeout(() => { if (isMounted) setRetryCount(c => c + 1) }, delay)
            }
          } else if (isMounted) {
            setStatus('error')
            setErrorMessage(errorMsg)
          }
        }
      } catch (e) {
        console.error('MiAuthCallbackPage: Exception', e)
        if (isMounted) {
          setStatus('error')
          setErrorMessage(e instanceof Error ? e.message : t('error.unknown'))
        }
      }
    })()

    return () => { isMounted = false }
  }, [retryCount])

  return (
    <main class="container">
      <article class="login-card">
        <header><h1>ログイン中...</h1></header>
        {status === 'checking' ? (
          <div class="loading-container"><p>認証確認中...</p></div>
        ) : status === 'success' ? (
          <div class="success-message">
            <div style={{ fontSize: '2rem', marginBottom: '0.5rem' }}>✓</div>
            <p>ログイン成功！</p>
            <p style={{ fontSize: '0.875rem', fontWeight: '400', marginTop: '0.5rem', color: '#158033' }}>
              ホームへ移動中...
            </p>
          </div>
        ) : status === 'permanent_error' ? (
          <div class="error-message">
            <p>セッションが期限切れか見つかりません。</p>
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
