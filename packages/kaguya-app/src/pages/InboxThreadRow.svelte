<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of InboxPage's inline ThreadRow sub-component. One row
  per note-being-interacted-with (Zulip-style), with expansion to show
  the individual notifications below.
-->

<script lang="ts">
  import type { NotificationView, NotificationType } from '../domain/notification/notificationView'
  import { typeLabel, fullHandle, notifHref } from '../domain/notification/notificationView'
  import { dismissInboxGroup } from '../domain/notification/notificationStore'
  import { isUnicodeEmoji } from '../domain/emoji/emojiOps'
  import { formatRelativeTime } from '../infra/timeFormat'
  import { currentLocale, t } from '../infra/i18n'
  import { proxyUrl } from '../infra/mediaProxy'
  import { instanceName } from '../domain/auth/appState'
  import ContentRenderer from '../ui/content/ContentRenderer.svelte'
  import { toTwemojiUrl } from '../ui/content/emojiHelpers'
  import { svelteSignal } from '../ui/svelteSignal.svelte'
  import { navigate } from '../ui/svelteRouter'

  export type ThreadGroup = {
    noteId: string
    noteText: string | undefined
    notifs: NotificationView[]
    latestAt: string
  }

  type Props = { thread: ThreadGroup; expanded: boolean; onToggle: () => void }
  let { thread, expanded, onToggle }: Props = $props()

  const instanceR = svelteSignal(instanceName)
  const localeR = svelteSignal(currentLocale)

  const href = $derived(`/notes/${thread.noteId}/${instanceR.value}`)

  const uniqueTypes = $derived.by<NotificationType[]>(() => {
    const seen = new Set<string>()
    const out: NotificationType[] = []
    for (const n of thread.notifs) {
      const key = typeof n.type_ === 'object' ? n.type_.tag : n.type_
      if (!seen.has(key)) { seen.add(key); out.push(n.type_) }
    }
    return out
  })

  const userSummary = $derived.by(() => {
    const seen = new Set<string>()
    const names: string[] = []
    for (const n of thread.notifs) {
      if (n.userName && !seen.has(n.userName)) {
        seen.add(n.userName)
        names.push(n.userName)
        if (names.length >= 3) break
      }
    }
    return names.join(', ') + (thread.notifs.length > 3 ? ` +${thread.notifs.length - 3}` : '')
  })

  const L = $derived((localeR.value, {
    dismissGroup: t('inbox.dismiss_group'),
    viewThread: t('inbox.view_thread'),
  }))

  function interactionIcon(type_: NotificationType): string {
    if (typeof type_ === 'object') return 'tabler:bell'
    switch (type_) {
      case 'Mention': return 'tabler:at'
      case 'Reply': return 'tabler:message-reply'
      case 'Renote': return 'tabler:repeat'
      case 'Quote': return 'tabler:quote'
      case 'Reaction': return 'tabler:mood-happy'
      default: return 'tabler:bell'
    }
  }

  function handleDismiss(e: MouseEvent | KeyboardEvent) {
    e.stopPropagation()
    dismissInboxGroup(thread.notifs.map((n) => n.id))
  }
</script>

<div class="inbox-group inbox-thread {expanded ? 'inbox-group-open' : ''}">
  <button
    class="inbox-group-header inbox-thread-header"
    type="button"
    onclick={onToggle}
    aria-expanded={expanded}
  >
    <div class="inbox-thread-type-icons">
      {#each uniqueTypes as type_ (typeof type_ === 'object' ? type_.tag : type_)}
        <iconify-icon class="inbox-thread-type-icon" icon={interactionIcon(type_)}></iconify-icon>
      {/each}
    </div>

    <div class="inbox-thread-info">
      {#if thread.noteText}
        <span class="inbox-thread-preview">
          <ContentRenderer text={thread.noteText} parseSimple={true} />
        </span>
      {:else}
        <span class="inbox-thread-preview inbox-thread-preview-empty">—</span>
      {/if}
      <span class="inbox-thread-users">{userSummary}</span>
    </div>

    <time class="inbox-thread-time">{formatRelativeTime(thread.latestAt)}</time>

    <span class="inbox-group-count">{thread.notifs.length}</span>

    <iconify-icon class="inbox-group-chevron" icon={expanded ? 'tabler:chevron-up' : 'tabler:chevron-down'}></iconify-icon>

    <span
      class="inbox-dismiss-btn"
      role="button"
      tabindex="0"
      title={L.dismissGroup}
      aria-label={L.dismissGroup}
      onclick={(e) => handleDismiss(e)}
      onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') handleDismiss(e) }}
    >
      <iconify-icon icon="tabler:x"></iconify-icon>
    </span>
  </button>

  {#if expanded}
    <div class="inbox-group-items">
      {#each thread.notifs as notif (notif.id)}
        {@const dest = notifHref(notif) ?? href}
        <div
          class="inbox-item inbox-item-clickable"
          role="button"
          tabindex="0"
          onclick={() => navigate(dest)}
          onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); navigate(dest) } }}
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

            {#if notif.reaction && notif.reactionUrl}
              <span class="inbox-item-reaction">
                <img class="mfm-emoji-image" src={proxyUrl(notif.reactionUrl)} alt={notif.reaction} loading="lazy" style="height: 1.5em" />
              </span>
            {:else if notif.reaction}
              <span class="inbox-item-reaction">
                {#if isUnicodeEmoji(notif.reaction)}
                  <img class="mfm-emoji" src={toTwemojiUrl(notif.reaction)} alt={notif.reaction} draggable={false} style="height: 1.5em" />
                {:else}
                  <span>{notif.reaction}</span>
                {/if}
              </span>
            {/if}

            {#if notif.noteText}
              <div class="inbox-item-note">
                <ContentRenderer text={notif.noteText} />
              </div>
            {/if}
          </div>
        </div>
      {/each}

      <div class="inbox-home-footer">
        <button class="inbox-see-all-btn" type="button" onclick={() => navigate(href)}>
          {L.viewThread}
        </button>
      </div>
    </div>
  {/if}
</div>
