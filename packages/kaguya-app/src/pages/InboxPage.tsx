// SPDX-License-Identifier: MPL-2.0

import { useState } from 'preact/hooks'
import { Layout } from '../ui/Layout'
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
import { ContentRenderer } from '../ui/content/ContentRenderer'
import { toTwemojiUrl } from '../ui/content/emojiComponents'
import { isUnicodeEmoji } from '../domain/emoji/emojiOps'
import { formatRelativeTime } from '../infra/timeFormat'
import { t } from '../infra/i18n'
import { proxyUrl } from '../infra/mediaProxy'
import { useLocation } from '../ui/router'
import { instanceName } from '../domain/auth/appState'

// ─── Types ───────────────────────────────────────────────────────────────────

type ThreadGroup = {
  noteId: string
  noteText: string | undefined
  notifs: NotificationView[]
  latestAt: string
}

type NonThreadGroupDef = { id: string; labelKey: string; icon: string }

const NON_THREAD_GROUPS: NonThreadGroupDef[] = [
  { id: 'follows', labelKey: 'inbox.group_follows', icon: 'tabler:user-plus' },
  { id: 'other',   labelKey: 'inbox.group_other',   icon: 'tabler:bell' },
]

// ─── Helpers ─────────────────────────────────────────────────────────────────

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

function interactionIcon(type_: NotificationType): string {
  if (typeof type_ === 'object') return 'tabler:bell'
  switch (type_) {
    case 'Mention': return 'tabler:at'
    case 'Reply':   return 'tabler:message-reply'
    case 'Renote':  return 'tabler:repeat'
    case 'Quote':   return 'tabler:quote'
    case 'Reaction': return 'tabler:mood-happy'
    default: return 'tabler:bell'
  }
}

// ─── Thread Row (Zulip-style: one row per note being interacted with) ─────────

function ThreadRow({ thread, expanded, onToggle }: {
  thread: ThreadGroup
  expanded: boolean
  onToggle: () => void
}) {
  const [, navigate] = useLocation()
  const localHost = instanceName.value
  const href = `/notes/${thread.noteId}/${localHost}`

  // Unique interaction types (preserving order of first occurrence)
  const seenTypes = new Set<string>()
  const uniqueTypes: NotificationType[] = []
  for (const n of thread.notifs) {
    const key = typeof n.type_ === 'object' ? n.type_.tag : n.type_
    if (!seenTypes.has(key)) {
      seenTypes.add(key)
      uniqueTypes.push(n.type_)
    }
  }

  // Up to 3 unique user names
  const seenUsers = new Set<string>()
  const userNames: string[] = []
  for (const n of thread.notifs) {
    if (n.userName && !seenUsers.has(n.userName)) {
      seenUsers.add(n.userName)
      userNames.push(n.userName)
      if (userNames.length >= 3) break
    }
  }
  const userSummary = userNames.join(', ') + (thread.notifs.length > 3 ? ` +${thread.notifs.length - 3}` : '')

  function handleDismiss(e: MouseEvent | KeyboardEvent) {
    e.stopPropagation()
    dismissInboxGroup(thread.notifs.map(n => n.id))
  }

  return (
    <div class={`inbox-group inbox-thread${expanded ? ' inbox-group-open' : ''}`}>
      <button
        class="inbox-group-header inbox-thread-header"
        type="button"
        onClick={onToggle}
        aria-expanded={expanded}
      >
        {/* Interaction type icons */}
        <div class="inbox-thread-type-icons">
          {uniqueTypes.map(type_ => (
            <iconify-icon
              key={typeof type_ === 'object' ? type_.tag : type_}
              class="inbox-thread-type-icon"
              icon={interactionIcon(type_)}
            />
          ))}
        </div>

        {/* Note preview + who interacted */}
        <div class="inbox-thread-info">
          {thread.noteText ? (
            <span class="inbox-thread-preview">
              <ContentRenderer text={thread.noteText} parseSimple />
            </span>
          ) : (
            <span class="inbox-thread-preview inbox-thread-preview-empty">—</span>
          )}
          <span class="inbox-thread-users">{userSummary}</span>
        </div>

        {/* Time */}
        <time class="inbox-thread-time">{formatRelativeTime(thread.latestAt)}</time>

        {/* Count badge */}
        <span class="inbox-group-count">{thread.notifs.length}</span>

        <iconify-icon
          class="inbox-group-chevron"
          icon={expanded ? 'tabler:chevron-up' : 'tabler:chevron-down'}
        />

        <span
          class="inbox-dismiss-btn"
          role="button"
          tabIndex={0}
          title={t('inbox.dismiss_group')}
          aria-label={t('inbox.dismiss_group')}
          onClick={e => handleDismiss(e as MouseEvent)}
          onKeyDown={(e: KeyboardEvent) => { if (e.key === 'Enter' || e.key === ' ') handleDismiss(e) }}
        >
          <iconify-icon icon="tabler:x" />
        </span>
      </button>

      {expanded && (
        <div class="inbox-group-items">
          {thread.notifs.map(notif => {
            const dest = notifHref(notif) ?? href
            return (
              <div
                key={notif.id}
                class="inbox-item inbox-item-clickable"
                onClick={() => navigate(dest)}
                role="button"
                tabIndex={0}
                onKeyDown={(e: KeyboardEvent) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); navigate(dest) } }}
              >
                {notif.userAvatarUrl && (
                  <img
                    class="inbox-item-avatar"
                    src={proxyUrl(notif.userAvatarUrl)}
                    alt=""
                    loading="lazy"
                  />
                )}
                <div class="inbox-item-body">
                  <div class="inbox-item-meta">
                    {notif.userName && (
                      <span class="inbox-item-user">
                        <ContentRenderer text={notif.userName} parseSimple />
                        <small class="inbox-item-handle"> {fullHandle(notif)}</small>
                      </span>
                    )}
                    <span class="inbox-item-type">{typeLabel(notif.type_)}</span>
                    <time class="inbox-item-time" dateTime={notif.createdAt}>
                      {formatRelativeTime(notif.createdAt)}
                    </time>
                  </div>

                  {notif.reaction && notif.reactionUrl ? (
                    <span class="inbox-item-reaction">
                      <img
                        class="mfm-emoji-image"
                        src={proxyUrl(notif.reactionUrl)}
                        alt={notif.reaction}
                        loading="lazy"
                        style={{ height: '1.5em' }}
                      />
                    </span>
                  ) : notif.reaction ? (
                    <span class="inbox-item-reaction">
                      {isUnicodeEmoji(notif.reaction)
                        ? <img class="mfm-emoji" src={toTwemojiUrl(notif.reaction)} alt={notif.reaction} draggable={false} style={{ height: '1.5em' }} />
                        : <span>{notif.reaction}</span>}
                    </span>
                  ) : null}

                  {notif.noteText && (
                    <div class="inbox-item-note">
                      <ContentRenderer text={notif.noteText} />
                    </div>
                  )}
                </div>
              </div>
            )
          })}

          <div class="inbox-home-footer">
            <button
              class="inbox-see-all-btn"
              type="button"
              onClick={() => navigate(href)}
            >
              {t('inbox.view_thread')}
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

// ─── Main Page ────────────────────────────────────────────────────────────────

export function InboxPage() {
  const allNotifs = notifications.value
  const dismissed = inboxDismissedIds.value
  const [, navigate] = useLocation()
  const [expanded, setExpanded] = useState<ReadonlySet<string>>(new Set())

  const items = allNotifs.filter(n => !dismissed.has(n.id))

  // ── Split into thread (has noteId) vs non-thread ──
  const threadMap = new Map<string, ThreadGroup>()
  const nonThreadNotifs: NotificationView[] = []

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
      nonThreadNotifs.push(notif)
    }
  }

  // Sort threads by latest activity (newest first)
  const threads = [...threadMap.values()].sort((a, b) =>
    b.latestAt.localeCompare(a.latestAt)
  )

  // Group non-thread notifs by type
  const nonThreadGrouped = new Map<string, NotificationView[]>()
  for (const notif of nonThreadNotifs) {
    const gid = nonThreadGroupId(notif.type_)
    const bucket = nonThreadGrouped.get(gid)
    if (bucket) bucket.push(notif)
    else nonThreadGrouped.set(gid, [notif])
  }

  const activeNonThreadGroups = NON_THREAD_GROUPS.filter(
    g => (nonThreadGrouped.get(g.id)?.length ?? 0) > 0
  )

  function toggleGroup(id: string) {
    setExpanded(prev => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  const isEmpty = threads.length === 0 && activeNonThreadGroups.length === 0

  return (
    <Layout>
      <div class="inbox-container">
        <div class="inbox-header">
          <h2 class="inbox-title">{t('inbox.title')}</h2>
          {items.length > 0 && (
            <button class="inbox-clear-btn" type="button" onClick={dismissAllInbox}>
              {t('inbox.clear_all')}
            </button>
          )}
        </div>

        {isEmpty ? (
          <div class="inbox-empty">
            <div class="inbox-empty-icon">✨</div>
            <p class="inbox-empty-text">{t('inbox.empty')}</p>
          </div>
        ) : (
          <div class="inbox-groups">
            {/* Thread groups — Zulip-style: one row per note being interacted with */}
            {threads.map(thread => (
              <ThreadRow
                key={thread.noteId}
                thread={thread}
                expanded={expanded.has(thread.noteId)}
                onToggle={() => toggleGroup(thread.noteId)}
              />
            ))}

            {/* Non-thread groups (follows, achievements, etc.) */}
            {activeNonThreadGroups.map(group => {
              const groupItems = nonThreadGrouped.get(group.id) ?? []
              const isExpanded = expanded.has(group.id)
              return (
                <div key={group.id} class={`inbox-group${isExpanded ? ' inbox-group-open' : ''}`}>
                  <button
                    class="inbox-group-header"
                    type="button"
                    onClick={() => toggleGroup(group.id)}
                    aria-expanded={isExpanded}
                  >
                    <iconify-icon class="inbox-group-icon" icon={group.icon} />
                    <span class="inbox-group-label">{t(group.labelKey)}</span>
                    <span class="inbox-group-count">{groupItems.length}</span>
                    <iconify-icon
                      class="inbox-group-chevron"
                      icon={isExpanded ? 'tabler:chevron-up' : 'tabler:chevron-down'}
                    />
                    <span
                      class="inbox-dismiss-btn"
                      role="button"
                      tabIndex={0}
                      title={t('inbox.dismiss_group')}
                      aria-label={t('inbox.dismiss_group')}
                      onClick={e => { e.stopPropagation(); dismissInboxGroup(groupItems.map(n => n.id)) }}
                      onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') { e.stopPropagation(); dismissInboxGroup(groupItems.map(n => n.id)) } }}
                    >
                      <iconify-icon icon="tabler:x" />
                    </span>
                  </button>

                  {isExpanded && (
                    <div class="inbox-group-items">
                      {groupItems.map(notif => {
                        const href = notifHref(notif)
                        return (
                          <div
                            key={notif.id}
                            class={`inbox-item${href ? ' inbox-item-clickable' : ''}`}
                            onClick={href ? () => navigate(href) : undefined}
                            role={href ? 'button' : undefined}
                            tabIndex={href ? 0 : undefined}
                            onKeyDown={href ? (e: KeyboardEvent) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); navigate(href) } } : undefined}
                          >
                            {notif.userAvatarUrl && (
                              <img
                                class="inbox-item-avatar"
                                src={proxyUrl(notif.userAvatarUrl)}
                                alt=""
                                loading="lazy"
                              />
                            )}
                            <div class="inbox-item-body">
                              <div class="inbox-item-meta">
                                {notif.userName && (
                                  <span class="inbox-item-user">
                                    <ContentRenderer text={notif.userName} parseSimple />
                                    <small class="inbox-item-handle"> {fullHandle(notif)}</small>
                                  </span>
                                )}
                                <span class="inbox-item-type">{typeLabel(notif.type_)}</span>
                                <time class="inbox-item-time" dateTime={notif.createdAt}>
                                  {formatRelativeTime(notif.createdAt)}
                                </time>
                              </div>
                              {notif.body && <p class="inbox-item-body-text">{notif.body}</p>}
                            </div>
                          </div>
                        )
                      })}
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        )}

        <div class="inbox-footer">
          <button
            class="inbox-see-all-btn"
            type="button"
            onClick={() => navigate('/timeline-inbox')}
          >
            {t('timeline_inbox.title')}
          </button>
          <button
            class="inbox-see-all-btn"
            type="button"
            onClick={() => navigate('/notifications')}
          >
            {t('inbox.see_all')}
          </button>
        </div>
      </div>
    </Layout>
  )
}
