<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of NotePoll.tsx. Poll UI with local optimistic voting
  (rolled back on backend failure), single / multiple choice, and
  expired display. Not yet mounted at runtime.
-->

<script lang="ts">
  import type { PollView } from '../../../domain/note/noteView'
  import { client, isLoggedIn, isReadOnlyMode } from '../../../domain/auth/appState'
  import * as Backend from '../../../lib/backend'
  import { showError } from '../../toastState'
  import { currentLocale, t } from '../../../infra/i18n'
  import { svelteSignal } from '../../svelteSignal.svelte'

  type Props = { noteId: string; poll: PollView }
  let { noteId, poll }: Props = $props()

  function isPollExpired(expiresAt: string | undefined): boolean {
    if (!expiresAt) return false
    return new Date(expiresAt) < new Date()
  }

  const localeR = svelteSignal(currentLocale)
  const loggedInR = svelteSignal(isLoggedIn)

  let localVoted = $state<number[]>(poll.choices.flatMap((c, i) => (c.isVoted ? [i] : [])))
  let localCounts = $state<number[]>(poll.choices.map((c) => c.votes))

  const readOnly = $derived((loggedInR.value, isReadOnlyMode()))
  const expired = $derived(isPollExpired(poll.expiresAt))
  const hasVoted = $derived(localVoted.length > 0)
  const canVote = $derived(loggedInR.value && !readOnly && !expired && (!hasVoted || poll.multiple))
  const totalVotes = $derived(localCounts.reduce((sum, v) => sum + v, 0))

  const L = $derived((localeR.value, {
    label: t('poll.label'),
    votes: t('poll.votes'),
    expired: t('poll.expired'),
    expiresAt: t('poll.expires_at'),
    voteFailed: t('poll.vote_failed'),
  }))

  function handleVote(index: number) {
    if (!canVote) return
    if (!poll.multiple && hasVoted) return
    if (localVoted.includes(index)) return

    const currentClient = client.peek()
    if (!currentClient) return

    localVoted = poll.multiple ? [...localVoted, index] : [index]
    localCounts = localCounts.map((v, i) => (i === index ? v + 1 : v))

    void (async () => {
      const result = await Backend.pollVote(currentClient, noteId, index)
      if (!result.ok) {
        showError(L.voteFailed)
        localVoted = localVoted.filter((i) => i !== index)
        localCounts = localCounts.map((v, i) => (i === index ? v - 1 : v))
      }
    })()
  }
</script>

<div
  class={`note-poll${hasVoted || expired ? ' note-poll--results' : ''}`}
  role={poll.multiple ? 'group' : 'radiogroup'}
  aria-label={L.label}
>
  {#each poll.choices as choice, index (index)}
    {@const votes = localCounts[index] ?? choice.votes}
    {@const voted = localVoted.includes(index)}
    {@const pct = totalVotes > 0 ? Math.round((votes / totalVotes) * 100) : 0}
    <button
      class={`poll-choice${voted ? ' poll-choice-voted' : ''}${canVote && !voted ? ' poll-choice-clickable' : ''}`}
      type="button"
      aria-pressed={voted}
      disabled={!canVote || voted}
      onclick={() => handleVote(index)}
    >
      <div class="poll-choice-bar" style="width: {pct}%"></div>
      {#if voted}
        <span class="poll-choice-check" aria-hidden="true">
          <iconify-icon icon="tabler:check"></iconify-icon>
        </span>
      {/if}
      <span class="poll-choice-text">{choice.text}</span>
      <span class="poll-choice-stats">{pct}% · {votes}{L.votes}</span>
    </button>
  {/each}
  <div class="poll-footer">
    <span class="poll-total">{totalVotes}{L.votes}</span>
    {#if expired}
      <span class="poll-expired">{L.expired}</span>
    {:else if poll.expiresAt}
      <span class="poll-expires">{L.expiresAt} {new Date(poll.expiresAt).toLocaleDateString()}</span>
    {/if}
  </div>
</div>
