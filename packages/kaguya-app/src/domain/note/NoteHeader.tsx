// SPDX-License-Identifier: MPL-2.0

import { Link } from '../../ui/router'
import type { UserView } from '../user/userView'
import { formatRelativeTime } from '../../infra/timeFormat'
import { instanceName } from '../auth/appState'
import { ContentRenderer } from '../../ui/content/ContentRenderer'
import { proxyAvatarUrl } from '../../infra/mediaProxy'

type Props = {
  user: UserView
  createdAt: string
  noteId?: string
  contextHost?: string
}

export function NoteHeader({ user, createdAt, noteId, contextHost }: Props) {
  const localHost = instanceName.value
  const ctxHost = contextHost ?? localHost
  const userHost = user.host ?? ctxHost
  const userPath = `/@${user.username}@${userHost}`
  const displayHandle = userHost === ctxHost ? `@${user.username}` : `@${user.username}@${userHost}`
  const noteHref = noteId ? `/notes/${noteId}/${ctxHost}` : undefined
  const relativeTime = formatRelativeTime(createdAt)

  return (
    <div class="note-header">
      <Link href={userPath} class="note-avatar-link">
        {user.avatarUrl ? (
          <img
            class="avatar"
            src={proxyAvatarUrl(user.avatarUrl)}
            alt={`${user.username}'s avatar`}
            loading="lazy"
            onError={e => { (e.target as HTMLElement).style.display = 'none' }}
            role="img"
          />
        ) : (
          <div class="avatar-placeholder" aria-label={`${user.username}'s avatar`} role="img" />
        )}
      </Link>
      <div class="note-author">
        <Link href={userPath} class="display-name-link">
          <span class="display-name">
            <ContentRenderer text={user.name} parseSimple />
          </span>
        </Link>
        <span class="username">{displayHandle}</span>
      </div>
      {noteHref ? (
        <Link href={noteHref} class="note-time-link">
          <time class="note-time" dateTime={createdAt}>{relativeTime}</time>
        </Link>
      ) : (
        <time class="note-time" dateTime={createdAt}>{relativeTime}</time>
      )}
    </div>
  )
}
