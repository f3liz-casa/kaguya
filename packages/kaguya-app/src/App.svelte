<!--
  SPDX-License-Identifier: MPL-2.0

  Root Svelte component — replaces KaguyaApp.tsx as of the M5 mount
  swap. Hosts LoadingBar + Toast + router branch + restoreSession()
  on mount.

  Routing surface (mirror of KaguyaApp.tsx's AppContent):
  - /miauth-callback                  → MiAuthCallbackPage (auth bypass)
  - /oauth-callback*                  → OAuthCallbackPage (auth bypass)
  - LoggedOut / LoginFailed           → LoginPage
  - LoggingIn / LoggedIn → currentPath:
      /                               → HomePage
      /inbox                          → InboxPage
      /timeline-inbox                 → TimelineInboxPage
      /notifications                  → NotificationsPage
      /performance                    → PerformancePage
      /add-account                    → LoginPage
      /settings                       → SettingsPage
      /notes/:noteId/:host            → NotePage
      /push/notes/:noteId             → push-redirect logic, then NotePage
      /notes                          → Layout + 'app.select_note'
      /push-manual                    → PushManualRegistrationPage
      /@<acct>                        → UserPage (catch-all)
      default                         → HomePage
-->

<script lang="ts">
  import { onMount } from 'svelte'
  import LoadingBar from './ui/LoadingBar.svelte'
  import Toast from './ui/Toast.svelte'
  import Layout from './ui/Layout.svelte'
  import HomePage from './pages/HomePage.svelte'
  import LoginPage from './pages/LoginPage.svelte'
  import NotePage from './pages/NotePage.svelte'
  import NotificationsPage from './pages/NotificationsPage.svelte'
  import InboxPage from './pages/InboxPage.svelte'
  import TimelineInboxPage from './pages/TimelineInboxPage.svelte'
  import SettingsPage from './pages/SettingsPage.svelte'
  import UserPage from './pages/UserPage.svelte'
  import MiAuthCallbackPage from './pages/MiAuthCallbackPage.svelte'
  import OAuthCallbackPage from './pages/OAuthCallbackPage.svelte'
  import PerformancePage from './pages/PerformancePage.svelte'
  import PushManualRegistrationPage from './pages/PushManualRegistrationPage.svelte'
  import { authState, accounts, activeAccountId, instanceName } from './domain/auth/appState'
  import { restoreSession, switchAccount } from './domain/auth/authManager'
  import { currentLocale, t } from './infra/i18n'
  import { currentPath, navigate } from './ui/svelteRouter'
  import { svelteSignal } from './ui/svelteSignal.svelte'

  const pathR = svelteSignal(currentPath)
  const authStateR = svelteSignal(authState)
  const accountsR = svelteSignal(accounts)
  const activeIdR = svelteSignal(activeAccountId)
  const instanceR = svelteSignal(instanceName)
  const localeR = svelteSignal(currentLocale)

  onMount(() => {
    const path = window.location.pathname
    if (path === '/oauth-callback' || path === '/miauth-callback') return
    void restoreSession()
  })

  const path = $derived(pathR.value)

  // Match note path: /notes/:noteId/:host
  const noteRoute = $derived.by<{ noteId: string; host: string } | null>(() => {
    const m = path.match(/^\/notes\/([^/]+)\/([^/]+)$/)
    if (!m) return null
    return { noteId: m[1], host: m[2] }
  })

  // Push notes redirect: /push/notes/:noteId
  const pushNoteId = $derived.by<string | null>(() => {
    const m = path.match(/^\/push\/notes\/([^/]+)$/)
    return m ? m[1] : null
  })

  // Catch-all user path: /@username@host or /@username
  const userRoute = $derived.by<{ username: string; host?: string } | null>(() => {
    if (!path.startsWith('/@')) return null
    const acct = path.slice(2)
    const idx = acct.indexOf('@')
    if (idx === -1) return { username: acct }
    return { username: acct.slice(0, idx), host: acct.slice(idx + 1) }
  })

  // Push redirect side effect: read userId, find matching account, then
  // navigate to /notes/:noteId/:host. Runs only while on /push/notes/:id.
  $effect(() => {
    if (!pushNoteId) return
    const nid = pushNoteId
    const params = new URLSearchParams(window.location.search)
    const userId = params.get('userId') ?? undefined
    const accs = accountsR.value
    const matched = userId ? accs.find((a) => a.misskeyUserId === userId) : undefined

    function go(host: string) {
      navigate(`/notes/${nid}/${host}`, true)
    }

    const activeIdVal = activeIdR.value
    if (matched && matched.id !== activeIdVal) {
      void switchAccount(matched.id).then(() => go(matched.host))
    } else if (matched) {
      go(matched.host)
    } else {
      go(instanceR.value)
    }
  })

  const auth = $derived(authStateR.value)
  const isCallback = $derived(path === '/miauth-callback' || path.startsWith('/oauth-callback'))
  const isLoggedIn = $derived(auth === 'LoggingIn' || auth === 'LoggedIn')

  const selectNoteText = $derived((localeR.value, t('app.select_note')))
</script>

<LoadingBar />
<Toast />

{#if path === '/miauth-callback'}
  <MiAuthCallbackPage />
{:else if path.startsWith('/oauth-callback')}
  <OAuthCallbackPage />
{:else if !isCallback && !isLoggedIn}
  <LoginPage />
{:else if path === '/'}
  <HomePage />
{:else if path === '/inbox'}
  <InboxPage />
{:else if path === '/timeline-inbox'}
  <TimelineInboxPage />
{:else if path === '/notifications'}
  <NotificationsPage />
{:else if path === '/performance'}
  <PerformancePage />
{:else if path === '/add-account'}
  <LoginPage />
{:else if path === '/settings'}
  <SettingsPage />
{:else if noteRoute}
  <NotePage noteId={noteRoute.noteId} host={noteRoute.host} />
{:else if pushNoteId}
  <Layout>
    <div class="loading-container"><p>{(localeR.value, t('app.loading'))}</p></div>
  </Layout>
{:else if path === '/notes'}
  <Layout>
    <div class="loading-container"><p>{selectNoteText}</p></div>
  </Layout>
{:else if path === '/push-manual'}
  <PushManualRegistrationPage />
{:else if userRoute}
  <UserPage username={userRoute.username} host={userRoute.host} />
{:else}
  <HomePage />
{/if}
