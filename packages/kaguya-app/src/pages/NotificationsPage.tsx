// SPDX-License-Identifier: MPL-2.0

import { Layout } from '../ui/Layout'
import { notifications, unreadCount, markAllRead } from '../domain/notification/notificationStore'
import { typeIcon, typeLabel, fullHandle, notifHref } from '../domain/notification/notificationView'
import type { NotificationView } from '../domain/notification/notificationView'
import { ContentRenderer } from '../ui/content/ContentRenderer'
import { toTwemojiUrl } from '../ui/content/emojiComponents'
import { isUnicodeEmoji } from '../domain/emoji/emojiOps'
import { formatRelativeTime } from '../infra/timeFormat'
import { t } from '../infra/i18n'
import { proxyUrl } from '../infra/mediaProxy'
import { useLocation } from '../ui/router'


export function NotificationsPage() {
  const notifs = notifications.value
  const unread = unreadCount.value
  const [, navigate] = useLocation()

  return (
    <Layout>
      <div class="notifications-container">
        <div class="notifications-header">
          <h2>{t('notifications.title')}</h2>
          {unread > 0 && (
            <button
              type="button"
              class="notifications-mark-read-btn"
              onClick={() => markAllRead()}
            >
              {t('notifications.mark_all_read')}
            </button>
          )}
        </div>
        {notifs.length === 0 ? (
          <div class="notifications-empty">
            <p>{t('notifications.empty')}</p>
          </div>
        ) : (
          <div class="notifications-list">
            {notifs.map(notif => {
              const href = notifHref(notif)
              return (
                <article
                  key={notif.id}
                  class={`notification-item${href ? ' notification-item-clickable' : ''}`}
                  onClick={href ? () => navigate(href) : undefined}
                  role={href ? 'button' : undefined}
                  tabIndex={href ? 0 : undefined}
                  onKeyDown={href ? (e: KeyboardEvent) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); navigate(href) } } : undefined}
                >
                  <div class="notification-icon">
                    <img class="mfm-emoji" src={toTwemojiUrl(typeIcon(notif.type_))} alt={typeIcon(notif.type_)} draggable={false} />
                  </div>
                  <div class="notification-body">
                    <div class="notification-meta">
                      {notif.userName && (
                        <span class="notification-user">
                          <ContentRenderer text={notif.userName} parseSimple />
                          <small class="notification-handle"> {fullHandle(notif)}</small>
                        </span>
                      )}
                      <span class="notification-type">{typeLabel(notif.type_)}</span>
                      <time class="notification-time" dateTime={notif.createdAt}>
                        {formatRelativeTime(notif.createdAt)}
                      </time>
                    </div>

                    {notif.reaction && notif.reactionUrl ? (
                      <span class="notification-reaction">
                        <img
                          class="mfm-emoji-image"
                          src={proxyUrl(notif.reactionUrl)}
                          alt={notif.reaction}
                          loading="lazy"
                          style={{ height: '1.5em' }}
                        />
                      </span>
                    ) : notif.reaction ? (
                      <span class="notification-reaction">
                        {isUnicodeEmoji(notif.reaction)
                          ? <img class="mfm-emoji" src={toTwemojiUrl(notif.reaction)} alt={notif.reaction} draggable={false} style={{ height: '1.5em' }} />
                          : <span>{notif.reaction}</span>}
                      </span>
                    ) : null}

                    {notif.noteText ? (
                      <div class="notification-note-text">
                        <ContentRenderer text={notif.noteText} />
                      </div>
                    ) : notif.body ? (
                      <p class="notification-body-text">{notif.body}</p>
                    ) : null}
                  </div>
                </article>
              )
            })}
          </div>
        )}
      </div>
    </Layout>
  )
}
