<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of NotificationsPage.tsx. First page-level callsite of
  ContentRenderer's full pipeline (parseSimple=false for noteText).
  Not yet mounted at runtime — the Preact .tsx page remains live
  until M5 mount swap.
-->

<script lang="ts">
  import Layout from '../ui/Layout.svelte'
  import { notifications, unreadCount, markAllRead } from '../domain/notification/notificationStore'
  import { typeIcon, typeLabel, fullHandle, notifHref } from '../domain/notification/notificationView'
  import ContentRenderer from '../ui/content/ContentRenderer.svelte'
  import { toTwemojiUrl } from '../ui/content/emojiHelpers'
  import { isUnicodeEmoji } from '../domain/emoji/emojiOps'
  import { formatRelativeTime } from '../infra/timeFormat'
  import { currentLocale, t } from '../infra/i18n'
  import { proxyUrl } from '../infra/mediaProxy'
  import { svelteSignal } from '../ui/svelteSignal.svelte'
  import { navigate } from '../ui/svelteRouter'

  const notifsR = svelteSignal(notifications)
  const unreadR = svelteSignal(unreadCount)
  const localeR = svelteSignal(currentLocale)

  const L = $derived((localeR.value, {
    title: t('notifications.title'),
    markAllRead: t('notifications.mark_all_read'),
    empty: t('notifications.empty'),
  }))
</script>

<Layout>
  <div class="notifications-container">
    <div class="notifications-header">
      <h2>{L.title}</h2>
      {#if unreadR.value > 0}
        <button
          type="button"
          class="notifications-mark-read-btn"
          onclick={() => markAllRead()}
        >
          {L.markAllRead}
        </button>
      {/if}
    </div>
    {#if notifsR.value.length === 0}
      <div class="notifications-empty">
        <p>{L.empty}</p>
      </div>
    {:else}
      <div class="notifications-list">
        {#each notifsR.value as notif (notif.id)}
          {@const href = notifHref(notif)}
          <article
            class={`notification-item${href ? ' notification-item-clickable' : ''}`}
            role={href ? 'button' : undefined}
            tabindex={href ? 0 : undefined}
            onclick={href ? () => navigate(href) : undefined}
            onkeydown={href ? (e: KeyboardEvent) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); navigate(href) } } : undefined}
          >
            <div class="notification-icon">
              <img class="mfm-emoji" src={toTwemojiUrl(typeIcon(notif.type_))} alt={typeIcon(notif.type_)} draggable={false} />
            </div>
            <div class="notification-body">
              <div class="notification-meta">
                {#if notif.userName}
                  <span class="notification-user">
                    <ContentRenderer text={notif.userName} parseSimple={true} />
                    <small class="notification-handle"> {fullHandle(notif)}</small>
                  </span>
                {/if}
                <span class="notification-type">{typeLabel(notif.type_)}</span>
                <time class="notification-time" datetime={notif.createdAt}>
                  {formatRelativeTime(notif.createdAt)}
                </time>
              </div>

              {#if notif.reaction && notif.reactionUrl}
                <span class="notification-reaction">
                  <img
                    class="mfm-emoji-image"
                    src={proxyUrl(notif.reactionUrl)}
                    alt={notif.reaction}
                    loading="lazy"
                    style="height: 1.5em"
                  />
                </span>
              {:else if notif.reaction}
                <span class="notification-reaction">
                  {#if isUnicodeEmoji(notif.reaction)}
                    <img class="mfm-emoji" src={toTwemojiUrl(notif.reaction)} alt={notif.reaction} draggable={false} style="height: 1.5em" />
                  {:else}
                    <span>{notif.reaction}</span>
                  {/if}
                </span>
              {/if}

              {#if notif.noteText}
                <div class="notification-note-text">
                  <ContentRenderer text={notif.noteText} />
                </div>
              {:else if notif.body}
                <p class="notification-body-text">{notif.body}</p>
              {/if}
            </div>
          </article>
        {/each}
      </div>
    {/if}
  </div>
</Layout>
