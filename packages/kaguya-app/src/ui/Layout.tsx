// SPDX-License-Identifier: MPL-2.0

import { useState, useEffect, useRef } from 'preact/hooks'
import { Link, useLocation } from './router'
import type { ComponentChildren } from 'preact'
import { instanceName } from '../domain/auth/appState'
import { unreadCount, inboxCount, initInbox } from '../domain/notification/notificationStore'
import { initFilteredTimeline } from '../domain/timeline/filteredTimelineStore'
import { init as themeInit, toggle as themeToggle, isDark, currentTheme } from './themeStore'
import { init as preferencesInit, quietMode, isQuiet as isQuietSignal, isQuietHoursActive, setQuietMode, toggleQuietMode } from './preferencesStore'
import { init as mediaProxyInit } from '../infra/mediaProxy'
import { init as i18nInit, t, currentLocale } from '../infra/i18n'
import { AccountSwitcher } from '../domain/account/AccountSwitcher'
import { PostForm } from './PostForm'

type Props = {
  children: ComponentChildren
}

export function Layout({ children }: Props) {
  const instName = instanceName.value
  const notifCount = unreadCount.value
  const inboxUnread = inboxCount.value
  const [location, navigate] = useLocation()
  const [showCompose, setShowCompose] = useState(false)
  const composeModalRef = useRef<HTMLDivElement | null>(null)

  useEffect(() => {
    i18nInit()
    themeInit()
    preferencesInit()
    mediaProxyInit()
    initInbox()
    initFilteredTimeline()
  }, [])

  useEffect(() => {
    if (!showCompose) return
    const modal: HTMLDivElement | null = composeModalRef.current
    if (!modal) return
    const prevFocus = document.activeElement as HTMLElement | null

    const focusables = () => Array.from(modal.querySelectorAll<HTMLElement>(
      'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])'
    )).filter(el => el.offsetParent !== null || el === document.activeElement)

    const initialList = focusables()
    const initial = initialList.find(el => el.tagName === 'TEXTAREA') ?? initialList[0]
    initial?.focus()

    function onKey(e: KeyboardEvent) {
      if (!modal) return
      if (e.key === 'Escape') {
        e.stopPropagation()
        setShowCompose(false)
        return
      }
      if (e.key !== 'Tab') return
      const list = focusables()
      if (list.length === 0) return
      const first = list[0]
      const last = list[list.length - 1]
      const active = document.activeElement as HTMLElement | null
      const insideModal = active != null && modal.contains(active)
      if (e.shiftKey && (active === first || !insideModal)) {
        e.preventDefault()
        last.focus()
      } else if (!e.shiftKey && (active === last || !insideModal)) {
        e.preventDefault()
        first.focus()
      }
    }
    document.addEventListener('keydown', onKey)

    return () => {
      document.removeEventListener('keydown', onKey)
      prevFocus?.focus()
    }
  }, [showCompose])

  // Subscribe to signals for re-rendering
  const _theme = currentTheme.value
  const _locale = currentLocale.value
  const darkMode = isDark()
  const manualQuiet = quietMode.value
  const quietHoursActive = isQuietHoursActive.value
  const isQuiet = isQuietSignal.value

  function isActive(path: string) { return location === path }

  function handleBack() {
    if (history.length > 1) history.back()
    else navigate('/')
  }

  function scrollMainToTop() {
    const main = document.querySelector<HTMLElement>('.layout-main > main')
    if (main) main.scrollTo({ top: 0, behavior: 'smooth' })
    else window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  // Home buttons double as "scroll to top" when already on /.
  // The scroll also brings the top-sentinel into view, which auto-flushes
  // any pending streamed notes — matches the pill-tap behavior for free.
  function handleHomeClick() {
    if (location === '/') scrollMainToTop()
    else navigate('/')
  }

  const isRootPage = location === '/' || location === '/notifications' || location === '/inbox'
    || location === '/timeline-inbox' || location === '/settings' || location === '/performance'
    || location === '/miauth-callback' || location.startsWith('/oauth-callback')

  return (
    <div class="layout">
      <nav class="left-sidebar" aria-label={t('nav.side_navigation')}>
        <Link href="/" class="sidebar-logo">
          <div class="sidebar-logo-icon">🌿</div>
        </Link>
        <div class="sidebar-nav-items">
          <button class={`sidebar-nav-btn${isActive('/') ? ' active' : ''}`} onClick={handleHomeClick} title={t('nav.home')} aria-label={t('nav.home')} type="button">
            <iconify-icon icon="tabler:home" />
          </button>
          <button class={`sidebar-nav-btn${isActive('/inbox') ? ' active' : ''}`} onClick={() => navigate('/inbox')} title={t('nav.inbox')} aria-label={t('nav.inbox')} type="button">
            <iconify-icon icon="tabler:inbox" />
            {inboxUnread > 0 && <span class="sidebar-notification-badge">{inboxUnread > 99 ? '99+' : inboxUnread}</span>}
          </button>
          <button class={`sidebar-nav-btn${isActive('/notifications') ? ' active' : ''}`} onClick={() => navigate('/notifications')} title={t('nav.notifications')} aria-label={t('nav.notifications')} type="button">
            <iconify-icon icon="tabler:bell" />
            {notifCount > 0 && <span class="sidebar-notification-badge">{notifCount > 99 ? '99+' : notifCount}</span>}
          </button>
        </div>
        <div class="sidebar-bottom">
          <button class="sidebar-nav-btn" onClick={toggleQuietMode}
            title={manualQuiet ? t('quiet_mode.off') : t('quiet_mode.on')}
            aria-label={manualQuiet ? t('quiet_mode.off') : t('quiet_mode.on')}
            aria-pressed={isQuiet} type="button">
            <iconify-icon icon={isQuiet ? 'tabler:player-play' : 'tabler:player-pause'} />
          </button>
          <button class="sidebar-nav-btn theme-toggle-sidebar" onClick={themeToggle}
            title={darkMode ? t('theme.switch_to_light') : t('theme.switch_to_dark')}
            aria-label={darkMode ? t('theme.switch_to_light') : t('theme.switch_to_dark')} type="button">
            <iconify-icon icon={darkMode ? 'tabler:sun' : 'tabler:moon'} />
          </button>
          <button class={`sidebar-nav-btn${isActive('/settings') ? ' active' : ''}`} onClick={() => navigate('/settings')} title={t('nav.settings')} aria-label={t('nav.settings')} type="button">
            <iconify-icon icon="tabler:settings" />
          </button>
        </div>
      </nav>

      <div class="layout-main">
        <header class="container-fluid">
          <nav>
            <ul>
              <li>
                {!isRootPage && (
                  <button class="header-back-btn" onClick={handleBack} title={t('nav.back')} aria-label={t('nav.back')} type="button">
                    <iconify-icon icon="tabler:arrow-left" />
                  </button>
                )}
                <Link href="/" class="header-logo-link" onClick={() => { if (location === '/') scrollMainToTop() }}>
                  <span class="header-leaf-icon">🌿</span>
                </Link>
                <strong class="app-title">{t('app.title')}</strong>
                {instName && <small class="instance-badge">{instName}</small>}
              </li>
            </ul>
            <ul>
              <li><Link href="/" class={`header-nav-link${isActive('/') ? ' active' : ''}`} onClick={() => { if (location === '/') scrollMainToTop() }}>{t('nav.home')}</Link></li>
              <li>
                <Link href="/notifications" class={`notification-bell header-nav-link${isActive('/notifications') ? ' active' : ''}`}>
                  🔔
                  {notifCount > 0 && <span class="notification-badge">{notifCount > 99 ? '99+' : notifCount}</span>}
                </Link>
              </li>
            </ul>
            <ul>
              <li>
                <button class="theme-toggle-btn" onClick={themeToggle}
                  title={darkMode ? t('theme.switch_to_light') : t('theme.switch_to_dark')}
                  aria-label={darkMode ? t('theme.switch_to_light') : t('theme.switch_to_dark')} type="button">
                  <iconify-icon icon={darkMode ? 'tabler:sun' : 'tabler:moon'} />
                </button>
              </li>
              <li><AccountSwitcher /></li>
            </ul>
          </nav>
        </header>
        {isQuiet && (
          <div class="quiet-status-strip" role="status" aria-live="polite">
            <span class="quiet-status-label">
              <iconify-icon icon="tabler:player-pause" />
              {quietHoursActive && !manualQuiet ? t('quiet_mode.hours_active') : t('quiet_mode.manual_active')}
            </span>
            {manualQuiet && (
              <button type="button" class="quiet-status-resume" onClick={() => setQuietMode(false)}>
                {t('quiet_mode.resume')}
              </button>
            )}
          </div>
        )}
        <main class="container">{children}</main>
        <footer class="container">
          <small class="footer-text">{t('app.tagline')}</small>
        </footer>
      </div>

      <nav class="bottom-nav" aria-label={t('nav.bottom_navigation')}>
        <button class={`bottom-nav-btn${isActive('/') ? ' active' : ''}`} onClick={handleHomeClick} title={t('nav.home')} aria-label={t('nav.home')} type="button">
          <iconify-icon icon="tabler:home" />
        </button>
        <button class={`bottom-nav-btn${isActive('/inbox') ? ' active' : ''}`} onClick={() => navigate('/inbox')} title={t('nav.inbox')} aria-label={t('nav.inbox')} type="button">
          <span class="bottom-nav-bell-wrapper">
            <iconify-icon icon="tabler:inbox" />
            {inboxUnread > 0 && <span class="notification-badge">{inboxUnread > 99 ? '99+' : inboxUnread}</span>}
          </span>
        </button>
        <button class={`bottom-nav-btn${isActive('/settings') ? ' active' : ''}`} onClick={() => navigate('/settings')} title={t('nav.settings')} aria-label={t('nav.settings')} type="button">
          <iconify-icon icon="tabler:settings" />
        </button>
      </nav>

      <button class="note-fab" type="button" onClick={() => setShowCompose(true)} title={t('compose.title')} aria-label={t('compose.title')}>
        <iconify-icon icon="tabler:pencil-plus" />
      </button>

      {showCompose && (
        <div class="compose-overlay" onClick={e => { if (e.target === e.currentTarget) setShowCompose(false) }}>
          <div
            class="compose-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="compose-modal-title"
            ref={composeModalRef}
          >
            <div class="compose-modal-header">
              <span id="compose-modal-title" class="compose-modal-title">{t('compose.title')}</span>
              <button type="button" class="compose-close-btn" onClick={() => setShowCompose(false)} aria-label={t('action.close')}>
                <iconify-icon icon="tabler:x" />
              </button>
            </div>
            <PostForm onPosted={() => setShowCompose(false)} />
          </div>
        </div>
      )}
    </div>
  )
}
