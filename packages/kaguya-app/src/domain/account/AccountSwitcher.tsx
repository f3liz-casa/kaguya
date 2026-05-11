// SPDX-License-Identifier: MPL-2.0

import { useState, useEffect, useRef } from 'preact/hooks'
import { useLocation } from '../../ui/router'
import { accounts, activeAccountId, isReadOnlyMode, getCurrentUserName } from '../auth/appState'
import { removeAccount } from './accountManager'
import { logout, switchAccount } from '../auth/authService'
import { displayLabel } from './account'
import { ContentRenderer } from '../../ui/content/ContentRenderer'
import { PushNotificationToggle } from '../../ui/PushNotificationToggle'
import { t } from '../../infra/i18n'
import { proxyAvatarUrl } from '../../infra/mediaProxy'

export function AccountSwitcher() {
  const [isOpen, setIsOpen] = useState(false)
  const currentAccounts = accounts.value
  const activeId = activeAccountId.value
  const userName = getCurrentUserName() ?? ''
  const readOnly = isReadOnlyMode()
  const [, navigate] = useLocation()
  const dropdownRef = useRef<HTMLDivElement | null>(null)

  useEffect(() => {
    if (!isOpen) return
    const handleClick = (e: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setIsOpen(false)
      }
    }
    document.addEventListener('click', handleClick)
    return () => document.removeEventListener('click', handleClick)
  }, [isOpen])

  function handleLogout() {
    setIsOpen(false)
    logout()
    navigate('/')
  }

  const activeAccount = currentAccounts.find(a => a.id === activeId)
  const activeHandle = activeAccount ? `@${activeAccount.username}` : userName
  const activeInstance = activeAccount?.host ?? ''
  const activeAvatarUrl = activeAccount?.avatarUrl ?? ''

  return (
    <div class="account-switcher" ref={dropdownRef}>
      <button
        class="account-switcher-trigger"
        onClick={() => setIsOpen(v => !v)}
        aria-expanded={isOpen}
        aria-label={t('account.menu')}
        type="button"
      >
        {activeAvatarUrl
          ? <img class="account-switcher-trigger-avatar" src={proxyAvatarUrl(activeAvatarUrl)} alt="" loading="lazy" />
          : <div class="account-switcher-trigger-avatar account-switcher-avatar-placeholder" />
        }
        <div class="account-switcher-trigger-info">
          <span class="account-switcher-name">{activeHandle}</span>
          {activeInstance && <span class="account-switcher-trigger-instance">{activeInstance}</span>}
        </div>
        {readOnly && <span class="readonly-badge-small">🔒</span>}
        <span class="account-switcher-arrow" aria-hidden="true">▼</span>
      </button>

      {isOpen && (
        <div class="account-switcher-dropdown" role="menu">
          {activeAccount && (
            <div class="account-switcher-item account-switcher-active">
              {activeAccount.avatarUrl
                ? <img class="account-switcher-avatar" src={proxyAvatarUrl(activeAccount.avatarUrl)} alt="" loading="lazy" />
                : <div class="account-switcher-avatar account-switcher-avatar-placeholder" />
              }
              <div class="account-switcher-info">
                <span class="account-switcher-active-name">
                  <ContentRenderer text={userName} parseSimple />
                </span>
                <span class="account-switcher-handle">{displayLabel(activeAccount)}</span>
              </div>
              {readOnly
                ? <span class="readonly-badge-small" title={t('login.permission_readonly')}>🔒</span>
                : <span class="account-switcher-active-check" aria-hidden="true">✓</span>
              }
            </div>
          )}

          {currentAccounts.filter(a => a.id !== activeId).length > 0 && (
            <>
              <div class="account-switcher-divider" />
              {currentAccounts.filter(a => a.id !== activeId).map(account => (
                <div
                  key={account.id}
                  class="account-switcher-item"
                  role="menuitem"
                  onClick={() => { setIsOpen(false); void switchAccount(account.id) }}
                >
                  {account.avatarUrl
                    ? <img class="account-switcher-avatar" src={proxyAvatarUrl(account.avatarUrl)} alt="" loading="lazy" />
                    : <div class="account-switcher-avatar account-switcher-avatar-placeholder" />
                  }
                  <span class="account-switcher-label">{displayLabel(account)}</span>
                  <button
                    class="account-switcher-remove"
                    onClick={e => { e.stopPropagation(); removeAccount(account.id) }}
                    aria-label={`${t('account.remove')}: ${displayLabel(account)}`}
                    type="button"
                  >
                    ×
                  </button>
                </div>
              ))}
            </>
          )}

          <div class="account-switcher-divider" />
          <div
            class="account-switcher-item account-switcher-add"
            role="menuitem"
            onClick={() => { setIsOpen(false); navigate('/add-account') }}
          >
            <span class="account-switcher-add-icon">＋</span>
            <span>{t('account.add')}</span>
          </div>

          <div class="account-switcher-divider" />
          <div class="account-switcher-item">
            <PushNotificationToggle />
          </div>

          <div class="account-switcher-divider" />
          <div class="account-switcher-item account-switcher-logout" role="menuitem" onClick={handleLogout}>
            <span>{t('account.logout')}</span>
          </div>
        </div>
      )}
    </div>
  )
}
