<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of AccountSwitcher.tsx. Not yet mounted at runtime —
  AccountSwitcher.tsx remains the live component until M1 mount swap.
-->

<script lang="ts">
  import { accounts, activeAccountId, isReadOnlyMode, getCurrentUserName } from '../../../domain/auth/appState'
  import { removeAccount } from '../../../domain/account/accountManager'
  import { logout, switchAccount } from '../../../domain/auth/authService'
  import { displayLabel } from '../../../domain/account/account'
  import ContentRenderer from '../../content/ContentRenderer.svelte'
  import PushNotificationToggle from '../../PushNotificationToggle.svelte'
  import { currentLocale, t } from '../../../infra/i18n'
  import { proxyAvatarUrl } from '../../../infra/mediaProxy'
  import { svelteSignal } from '../../svelteSignal.svelte'
  import { navigate } from '../../svelteRouter'

  const accountsR = svelteSignal(accounts)
  const activeIdR = svelteSignal(activeAccountId)
  const localeR = svelteSignal(currentLocale)

  let isOpen = $state(false)
  let dropdownEl = $state<HTMLDivElement | null>(null)

  const userName = $derived((accountsR.value, activeIdR.value, getCurrentUserName() ?? ''))
  const readOnly = $derived((accountsR.value, activeIdR.value, isReadOnlyMode()))
  const activeAccount = $derived(accountsR.value.find(a => a.id === activeIdR.value))
  const activeHandle = $derived(activeAccount ? `@${activeAccount.username}` : userName)
  const activeInstance = $derived(activeAccount?.host ?? '')
  const activeAvatarUrl = $derived(activeAccount?.avatarUrl ?? '')
  const otherAccounts = $derived(accountsR.value.filter(a => a.id !== activeIdR.value))

  // Locale-keyed labels hoisted via $derived so each t() call re-runs on
  // locale switch through localeR.value's dependency in the expression.
  const L = $derived((localeR.value, {
    menu: t('account.menu'),
    permissionReadonly: t('login.permission_readonly'),
    remove: t('account.remove'),
    add: t('account.add'),
    logout: t('account.logout'),
  }))

  $effect(() => {
    if (!isOpen) return
    const handleClick = (e: MouseEvent) => {
      if (dropdownEl && !dropdownEl.contains(e.target as Node)) {
        isOpen = false
      }
    }
    document.addEventListener('click', handleClick)
    return () => document.removeEventListener('click', handleClick)
  })

  function handleLogout() {
    isOpen = false
    logout()
    navigate('/')
  }
</script>

<div class="account-switcher" bind:this={dropdownEl}>
  <button
    class="account-switcher-trigger"
    type="button"
    aria-expanded={isOpen}
    aria-label={L.menu}
    onclick={() => { isOpen = !isOpen }}
  >
    {#if activeAvatarUrl}
      <img class="account-switcher-trigger-avatar" src={proxyAvatarUrl(activeAvatarUrl)} alt="" loading="lazy" />
    {:else}
      <div class="account-switcher-trigger-avatar account-switcher-avatar-placeholder"></div>
    {/if}
    <div class="account-switcher-trigger-info">
      <span class="account-switcher-name">{activeHandle}</span>
      {#if activeInstance}
        <span class="account-switcher-trigger-instance">{activeInstance}</span>
      {/if}
    </div>
    {#if readOnly}
      <span class="readonly-badge-small">🔒</span>
    {/if}
    <span class="account-switcher-arrow" aria-hidden="true">▼</span>
  </button>

  {#if isOpen}
    <div class="account-switcher-dropdown" role="menu">
      {#if activeAccount}
        <div class="account-switcher-item account-switcher-active">
          {#if activeAccount.avatarUrl}
            <img class="account-switcher-avatar" src={proxyAvatarUrl(activeAccount.avatarUrl)} alt="" loading="lazy" />
          {:else}
            <div class="account-switcher-avatar account-switcher-avatar-placeholder"></div>
          {/if}
          <div class="account-switcher-info">
            <span class="account-switcher-active-name">
              <ContentRenderer text={userName} parseSimple={true} />
            </span>
            <span class="account-switcher-handle">{displayLabel(activeAccount)}</span>
          </div>
          {#if readOnly}
            <span class="readonly-badge-small" title={L.permissionReadonly}>🔒</span>
          {:else}
            <span class="account-switcher-active-check" aria-hidden="true">✓</span>
          {/if}
        </div>
      {/if}

      {#if otherAccounts.length > 0}
        <div class="account-switcher-divider"></div>
        {#each otherAccounts as account (account.id)}
          <div
            class="account-switcher-item"
            role="menuitem"
            tabindex="0"
            onclick={() => { isOpen = false; void switchAccount(account.id) }}
            onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { isOpen = false; void switchAccount(account.id) } }}
          >
            {#if account.avatarUrl}
              <img class="account-switcher-avatar" src={proxyAvatarUrl(account.avatarUrl)} alt="" loading="lazy" />
            {:else}
              <div class="account-switcher-avatar account-switcher-avatar-placeholder"></div>
            {/if}
            <span class="account-switcher-label">{displayLabel(account)}</span>
            <button
              class="account-switcher-remove"
              type="button"
              aria-label={`${L.remove}: ${displayLabel(account)}`}
              onclick={(e) => { e.stopPropagation(); removeAccount(account.id) }}
            >
              ×
            </button>
          </div>
        {/each}
      {/if}

      <div class="account-switcher-divider"></div>
      <div
        class="account-switcher-item account-switcher-add"
        role="menuitem"
        tabindex="0"
        onclick={() => { isOpen = false; navigate('/add-account') }}
        onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { isOpen = false; navigate('/add-account') } }}
      >
        <span class="account-switcher-add-icon">＋</span>
        <span>{L.add}</span>
      </div>

      <div class="account-switcher-divider"></div>
      <div class="account-switcher-item">
        <PushNotificationToggle />
      </div>

      <div class="account-switcher-divider"></div>
      <div
        class="account-switcher-item account-switcher-logout"
        role="menuitem"
        tabindex="0"
        onclick={handleLogout}
        onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') handleLogout() }}
      >
        <span>{L.logout}</span>
      </div>
    </div>
  {/if}
</div>
