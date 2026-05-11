// SPDX-License-Identifier: MPL-2.0

import { useEffect } from 'preact/hooks'
import { LocationProvider, Router, useLocation } from 'preact-iso'
import { LoadingBar } from './ui/LoadingBar'
import { Toast } from './ui/Toast'
import { authState, accounts, instanceName, activeAccountId } from './domain/auth/appState'
import { restoreSession, switchAccount } from './domain/auth/authManager'
import { HomePage } from './pages/HomePage'
import { LoginPage } from './pages/LoginPage'
import { NotePage } from './pages/NotePage'
import { NotificationsPage } from './pages/NotificationsPage'
import { InboxPage } from './pages/InboxPage'
import { TimelineInboxPage } from './pages/TimelineInboxPage'
import { SettingsPage } from './pages/SettingsPage'
import { UserPage } from './pages/UserPage'
import { MiAuthCallbackPage } from './pages/MiAuthCallbackPage'
import { OAuthCallbackPage } from './pages/OAuthCallbackPage'
import { PerformancePage } from './pages/PerformancePage'
import { PushManualRegistrationPage } from './pages/PushManualRegistrationPage'
import { Layout } from './ui/Layout'
import { t } from './infra/i18n'

const _isSsr: boolean = (import.meta as any).env?.SSR ?? false

// ---------------------------------------------------------------------------
// Route wrapper components — each declares `path` for the Router to match,
// then delegates to the real page component.
// ---------------------------------------------------------------------------

type RouteProps = { path?: string; default?: boolean }

// Typed params injected by preact-iso's Router via cloneElement
type NoteRouteProps = RouteProps & { noteId?: string; host?: string }
type PushRouteProps = RouteProps & { noteId?: string }

function HomeRoute(_props: RouteProps) { return <HomePage /> }
function NotificationsRoute(_props: RouteProps) { return <NotificationsPage /> }
function InboxRoute(_props: RouteProps) { return <InboxPage /> }
function TimelineInboxRoute(_props: RouteProps) { return <TimelineInboxPage /> }
function PerformanceRoute(_props: RouteProps) { return <PerformancePage /> }
function AddAccountRoute(_props: RouteProps) { return <LoginPage /> }
function SettingsRoute(_props: RouteProps) { return <SettingsPage /> }
function PushManualRoute(_props: RouteProps) { return <PushManualRegistrationPage /> }

function NotesIndexRoute(_props: RouteProps) {
  return (
    <Layout>
      <div class="loading-container"><p>{t('app.select_note')}</p></div>
    </Layout>
  )
}

function NotePageRoute({ noteId = '', host = '' }: NoteRouteProps) {
  return <NotePage noteId={noteId} host={host} />
}

function PushNoteRoute({ noteId = '' }: PushRouteProps) {
  const loc = useLocation()

  useEffect(() => {
    const params = new URLSearchParams(window.location.search)
    const userId = params.get('userId') ?? undefined
    const accs = accounts.value
    const matched = userId ? accs.find(a => a.misskeyUserId === userId) : undefined

    function go(host: string) {
      loc.route(`/notes/${noteId}/${host}`, true)
    }

    const activeIdVal = activeAccountId.value
    if (matched && matched.id !== activeIdVal) {
      void switchAccount(matched.id).then(() => go(matched.host))
    } else if (matched) {
      go(matched.host)
    } else {
      go(instanceName.value)
    }
  }, [])

  return (
    <Layout>
      <div class="loading-container"><p>{t('app.loading')}</p></div>
    </Layout>
  )
}

function parseAcct(acct: string): [string, string | undefined] {
  const idx = acct.indexOf('@')
  if (idx === -1) return [acct, undefined]
  return [acct.slice(0, idx), acct.slice(idx + 1)]
}

function CatchAllRoute({ path = '' }: RouteProps) {
  if (path.startsWith('/@')) {
    const acct = path.slice(2)
    const [username, host] = parseAcct(acct)
    return <UserPage username={username} host={host} />
  }
  return <HomePage />
}

// ---------------------------------------------------------------------------
// AppContent — lives inside LocationProvider so useLocation() resolves correctly
// ---------------------------------------------------------------------------

function AppContent() {
  const loc = useLocation()
  const location = loc.path
  const currentAuthState = authState.value

  const loggedInRoutes = (
    <Router>
      <HomeRoute path="/" />
      <InboxRoute path="/inbox" />
      <TimelineInboxRoute path="/timeline-inbox" />
      <NotificationsRoute path="/notifications" />
      <PerformanceRoute path="/performance" />
      <AddAccountRoute path="/add-account" />
      <SettingsRoute path="/settings" />
      <NotePageRoute path="/notes/:noteId/:host" />
      <PushNoteRoute path="/push/notes/:noteId" />
      <NotesIndexRoute path="/notes" />
      <PushManualRoute path="/push-manual" />
      <CatchAllRoute default />
    </Router>
  )

  if (_isSsr) return loggedInRoutes

  // Callback pages must always render regardless of auth state,
  // so they can show errors without being redirected away.
  if (location === '/miauth-callback') return <MiAuthCallbackPage />
  if (location.startsWith('/oauth-callback')) return <OAuthCallbackPage />

  if (currentAuthState === 'LoggingIn' || currentAuthState === 'LoggedIn') return loggedInRoutes

  // LoggedOut or LoginFailed
  return <LoginPage />
}

// ---------------------------------------------------------------------------
// Root component
// ---------------------------------------------------------------------------

export function KaguyaApp() {
  useEffect(() => {
    // Skip session restoration on OAuth/MiAuth callback pages —
    // those pages handle auth themselves and restoreSession would race.
    const path = window.location.pathname
    if (path === '/oauth-callback' || path === '/miauth-callback') return
    void restoreSession()
  }, [])

  return (
    <>
      <LoadingBar />
      <Toast />
      <LocationProvider>
        <AppContent />
      </LocationProvider>
    </>
  )
}
