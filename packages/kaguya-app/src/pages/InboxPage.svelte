<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of InboxPage.tsx. Notifications grouped two ways:
  thread groups (one row per noteId being interacted with, Zulip-
  style, rendered via InboxThreadRow.svelte) and non-thread groups
  (follows / other, expanded inline). Dismissed notifications hidden
  via inboxDismissedIds signal.

  Not yet mounted at runtime — InboxPage.tsx remains the live page
  until M5 mount swap.
-->

<script lang="ts">
  import Layout from '../ui/Layout.svelte'
  import {
    notifications,
    inboxDismissedIds,
    dismissInboxGroup,
    dismissAllInbox,
  } from '../domain/notification/notificationStore'
  import {
    typeLabel,
    fullHandle,
    notifHref,
  } from '../domain/notification/notificationView'
  import type { NotificationView, NotificationType } from '../domain/notification/notificationView'
  import ContentRenderer from '../ui/content/ContentRenderer.svelte'
  import { formatRelativeTime } from '../infra/timeFormat'
  import { currentLocale, t } from '../infra/i18n'
  import { proxyUrl } from '../infra/mediaProxy'
  import { svelteSignal } from '../ui/svelteSignal.svelte'
  import { navigate } from '../ui/svelteRouter'
  import InboxThreadRow, { type ThreadGroup } from './InboxThreadRow.svelte'

  type NonThreadGroupDef = { id: string; labelKey: string; icon: string }

  const NON_THREAD_GROUPS: NonThreadGroupDef[] = [
    { id: 'follows', labelKey: 'inbox.group_follows', icon: 'tabler:user-plus' },
    { id: 'other', labelKey: 'inbox.group_other', icon: 'tabler:bell' },
  ]

  function nonThreadGroupId(type_: NotificationType): string {
    if (typeof type_ === 'object') return 'other'
    switch (type_) {
      case 'Follow':
      case 'ReceiveFollowRequest':
      case 'FollowRequestAccepted':
        return 'follows'
      default:
        return 'other'
    }
  }

  const notifsR = svelteSignal(notifications)
  const dismissedR = svelteSignal(inboxDismissedIds)
  const localeR = svelteSignal(currentLocale)

  let expanded = $state<Set<string>>(new Set())

  const items = $derived(notifsR.value.filter((n) => !dismissedR.value.has(n.id)))

  const groups = $derived.by(() => {
    const threadMap = new Map<string, ThreadGroup>()
    const nonThread: NotificationView[] = []
    for (const notif of items) {
      if (notif.noteId) {
        const thread = threadMap.get(notif.noteId)
        if (thread) {
          thread.notifs.push(notif)
          if (notif.createdAt > thread.latestAt) thread.latestAt = notif.createdAt
        } else {
          threadMap.set(notif.noteId, {
            noteId: notif.noteId,
            noteText: notif.noteText,
            notifs: [notif],
            latestAt: notif.createdAt,
          })
        }
      } else {
        nonThread.push(notif)
      }
    }
    const threads = [...threadMap.values()].sort((a, b) => b.latestAt.localeCompare(a.latestAt))
    const nonThreadGrouped = new Map<string, NotificationView[]>()
    for (const notif of nonThread) {
      const gid = nonThreadGroupId(notif.type_)
      const bucket = nonThreadGrouped.get(gid)
      if (bucket) bucket.push(notif)
      else nonThreadGrouped.set(gid, [notif])
    }
    const activeNonThreadGroups = NON_THREAD_GROUPS.filter(
      (g) => (nonThreadGrouped.get(g.id)?.length ?? 0) > 0,
    )
    return { threads, nonThreadGrouped, activeNonThreadGroups }
  })

  const isEmpty = $derived(groups.threads.length === 0 && groups.activeNonThreadGroups.length === 0)

  function toggleGroup(id: string) {
    const next = new Set(expanded)
    if (next.has(id)) next.delete(id)
    else next.add(id)
    expanded = next
  }

  const L = $derived((localeR.value, {
    title: t('inbox.title'),
    clearAll: t('inbox.clear_all'),
    empty: t('inbox.empty'),
    dismissGroup: t('inbox.dismiss_group'),
    seeAll: t('inbox.see_all'),
    timelineInbox: t('timeline_inbox.title'),
  }))

  function groupLabel(key: string): string {
    void localeR.value
    return t(key)
  }
</script>

<Layout>
  <div class="inbox-container">
    <div class="inbox-header">
      <h2 class="inbox-title">{L.title}</h2>
      {#if items.length > 0}
        <button class="inbox-clear-btn" type="button" onclick={dismissAllInbox}>
          {L.clearAll}
        </button>
      {/if}
    </div>

    {#if isEmpty}
      <div class="inbox-empty">
        <div class="inbox-empty-icon">✨</div>
        <p class="inbox-empty-text">{L.empty}</p>
      </div>
    {:else}
      <div class="inbox-groups">
        {#each groups.threads as thread (thread.noteId)}
          <InboxThreadRow
            {thread}
            expanded={expanded.has(thread.noteId)}
            onToggle={() => toggleGroup(thread.noteId)}
          />
        {/each}

        {#each groups.activeNonThreadGroups as group (group.id)}
          {@const groupItems = groups.nonThreadGrouped.get(group.id) ?? []}
          {@const isExpanded = expanded.has(group.id)}
          <div class="inbox-group {isExpanded ? 'inbox-group-open' : ''}">
            <button
              class="inbox-group-header"
              type="button"
              onclick={() => toggleGroup(group.id)}
              aria-expanded={isExpanded}
            >
              <iconify-icon class="inbox-group-icon" icon={group.icon}></iconify-icon>
              <span class="inbox-group-label">{groupLabel(group.labelKey)}</span>
              <span class="inbox-group-count">{groupItems.length}</span>
              <iconify-icon class="inbox-group-chevron" icon={isExpanded ? 'tabler:chevron-up' : 'tabler:chevron-down'}></iconify-icon>
              <span
                class="inbox-dismiss-btn"
                role="button"
                tabindex="0"
                title={L.dismissGroup}
                aria-label={L.dismissGroup}
                onclick={(e) => { e.stopPropagation(); dismissInboxGroup(groupItems.map((n) => n.id)) }}
                onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.stopPropagation(); dismissInboxGroup(groupItems.map((n) => n.id)) } }}
              >
                <iconify-icon icon="tabler:x"></iconify-icon>
              </span>
            </button>

            {#if isExpanded}
              <div class="inbox-group-items">
                {#each groupItems as notif (notif.id)}
                  {@const href = notifHref(notif)}
                  <div
                    class="inbox-item {href ? 'inbox-item-clickable' : ''}"
                    role={href ? 'button' : undefined}
                    tabindex={href ? 0 : undefined}
                    onclick={href ? () => navigate(href) : undefined}
                    onkeydown={href ? (e: KeyboardEvent) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); navigate(href) } } : undefined}
                  >
                    {#if notif.userAvatarUrl}
                      <img class="inbox-item-avatar" src={proxyUrl(notif.userAvatarUrl)} alt="" loading="lazy" />
                    {/if}
                    <div class="inbox-item-body">
                      <div class="inbox-item-meta">
                        {#if notif.userName}
                          <span class="inbox-item-user">
                            <ContentRenderer text={notif.userName} parseSimple={true} />
                            <small class="inbox-item-handle"> {fullHandle(notif)}</small>
                          </span>
                        {/if}
                        <span class="inbox-item-type">{typeLabel(notif.type_)}</span>
                        <time class="inbox-item-time" datetime={notif.createdAt}>
                          {formatRelativeTime(notif.createdAt)}
                        </time>
                      </div>
                      {#if notif.body}
                        <p class="inbox-item-body-text">{notif.body}</p>
                      {/if}
                    </div>
                  </div>
                {/each}
              </div>
            {/if}
          </div>
        {/each}
      </div>
    {/if}

    <div class="inbox-footer">
      <button class="inbox-see-all-btn" type="button" onclick={() => navigate('/timeline-inbox')}>
        {L.timelineInbox}
      </button>
      <button class="inbox-see-all-btn" type="button" onclick={() => navigate('/notifications')}>
        {L.seeAll}
      </button>
    </div>
  </div>
</Layout>
