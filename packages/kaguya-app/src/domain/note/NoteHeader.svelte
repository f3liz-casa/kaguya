<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of NoteHeader.tsx. Avatar + display-name + relative time
  header for a note card. Not yet mounted at runtime.
-->

<script lang="ts">
  import Link from '../../ui/Link.svelte'
  import type { UserView } from '../user/userView'
  import { formatRelativeTime } from '../../infra/timeFormat'
  import { instanceName } from '../auth/appState'
  import ContentRenderer from '../../ui/content/ContentRenderer.svelte'
  import { proxyAvatarUrl } from '../../infra/mediaProxy'
  import { svelteSignal } from '../../ui/svelteSignal.svelte'

  type Props = {
    user: UserView
    createdAt: string
    noteId?: string
    contextHost?: string
  }
  let { user, createdAt, noteId, contextHost }: Props = $props()

  const instanceR = svelteSignal(instanceName)

  const ctxHost = $derived(contextHost ?? instanceR.value)
  const userHost = $derived(user.host ?? ctxHost)
  const userPath = $derived(`/@${user.username}@${userHost}`)
  const displayHandle = $derived(userHost === ctxHost ? `@${user.username}` : `@${user.username}@${userHost}`)
  const noteHref = $derived(noteId ? `/notes/${noteId}/${ctxHost}` : undefined)
  const relativeTime = $derived(formatRelativeTime(createdAt))
</script>

<div class="note-header">
  <Link href={userPath} class="note-avatar-link">
    {#if user.avatarUrl}
      <img
        class="avatar"
        src={proxyAvatarUrl(user.avatarUrl)}
        alt={`${user.username}'s avatar`}
        loading="lazy"
        onerror={(e) => { (e.currentTarget as HTMLElement).style.display = 'none' }}
        role="img"
      />
    {:else}
      <div class="avatar-placeholder" aria-label={`${user.username}'s avatar`} role="img"></div>
    {/if}
  </Link>
  <div class="note-author">
    <Link href={userPath} class="display-name-link">
      <span class="display-name">
        <ContentRenderer text={user.name} parseSimple={true} />
      </span>
    </Link>
    <span class="username">{displayHandle}</span>
  </div>
  {#if noteHref}
    <Link href={noteHref} class="note-time-link">
      <time class="note-time" datetime={createdAt}>{relativeTime}</time>
    </Link>
  {:else}
    <time class="note-time" datetime={createdAt}>{relativeTime}</time>
  {/if}
</div>
