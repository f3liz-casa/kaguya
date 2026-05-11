// SPDX-License-Identifier: MPL-2.0

import { useState } from 'preact/hooks'
import type { PollView } from './noteView'
import { client, isLoggedIn, isReadOnlyMode } from '../auth/appState'
import * as Backend from '../../lib/backend'
import { showError } from '../../ui/toastState'
import { t } from '../../infra/i18n'

type Props = {
  noteId: string
  poll: PollView
}

function isPollExpired(expiresAt: string | undefined): boolean {
  if (!expiresAt) return false
  return new Date(expiresAt) < new Date()
}

export function NotePoll({ noteId, poll }: Props) {
  const [localVoted, setLocalVoted] = useState<number[]>(
    poll.choices.flatMap((c, i) => (c.isVoted ? [i] : []))
  )
  const [localCounts, setLocalCounts] = useState<number[]>(poll.choices.map(c => c.votes))
  const loggedIn = isLoggedIn.value
  const readOnly = isReadOnlyMode()
  const expired = isPollExpired(poll.expiresAt)

  const hasVoted = localVoted.length > 0
  const canVote = loggedIn && !readOnly && !expired && (!hasVoted || poll.multiple)

  const totalVotes = localCounts.reduce((sum, v) => sum + v, 0)

  function handleVote(index: number) {
    if (!canVote) return
    if (!poll.multiple && hasVoted) return
    if (localVoted.includes(index)) return

    const currentClient = client.value
    if (!currentClient) return

    setLocalVoted(prev => poll.multiple ? [...prev, index] : [index])
    setLocalCounts(prev => prev.map((v, i) => (i === index ? v + 1 : v)))

    void (async () => {
      const result = await Backend.pollVote(currentClient, noteId, index)
      if (!result.ok) {
        showError(t('poll.vote_failed'))
        setLocalVoted(prev => prev.filter(i => i !== index))
        setLocalCounts(prev => prev.map((v, i) => (i === index ? v - 1 : v)))
      }
    })()
  }

  return (
    <div
      class={`note-poll${hasVoted || expired ? ' note-poll--results' : ''}`}
      role={poll.multiple ? 'group' : 'radiogroup'}
      aria-label={t('poll.label')}
    >
      {poll.choices.map((choice, index) => {
        const votes = localCounts[index] ?? choice.votes
        const voted = localVoted.includes(index)
        const pct = totalVotes > 0 ? Math.round((votes / totalVotes) * 100) : 0

        return (
          <button
            key={index}
            class={`poll-choice${voted ? ' poll-choice-voted' : ''}${canVote && !voted ? ' poll-choice-clickable' : ''}`}
            onClick={() => handleVote(index)}
            disabled={!canVote || voted}
            type="button"
            aria-pressed={voted}
          >
            <div class="poll-choice-bar" style={{ width: `${pct}%` }} />
            {voted && (
              <span class="poll-choice-check" aria-hidden="true">
                <iconify-icon icon="tabler:check" />
              </span>
            )}
            <span class="poll-choice-text">{choice.text}</span>
            <span class="poll-choice-stats">{pct}% · {votes}{t('poll.votes')}</span>
          </button>
        )
      })}
      <div class="poll-footer">
        <span class="poll-total">{totalVotes}{t('poll.votes')}</span>
        {expired ? (
          <span class="poll-expired">{t('poll.expired')}</span>
        ) : poll.expiresAt ? (
          <span class="poll-expires">{t('poll.expires_at')} {new Date(poll.expiresAt).toLocaleDateString()}</span>
        ) : null}
      </div>
    </div>
  )
}
