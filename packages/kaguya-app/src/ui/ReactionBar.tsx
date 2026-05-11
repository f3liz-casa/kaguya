// SPDX-License-Identifier: MPL-2.0

import type { ReactionAcceptance } from '../infra/sharedTypes'
import { useReactionBar } from './reactionBarHook'
import { ReactionButton } from './ReactionButton'
import { EmojiPicker } from '../domain/emoji/EmojiPicker'
import { t } from '../infra/i18n'

type Props = {
  noteId: string
  reactions: Record<string, number>
  reactionEmojis: Record<string, string>
  myReaction: string | undefined
  reactionAcceptance: ReactionAcceptance | undefined
}

export function ReactionBar({ noteId, reactions, reactionEmojis, myReaction, reactionAcceptance }: Props) {
  const {
    pendingReaction, showEmojiPicker, reactionArray, optimisticMyReaction,
    isLoggedIn, isReadOnly, handleReactionClick, handleEmojiSelect,
    openEmojiPicker, closeEmojiPicker,
  } = useReactionBar({ noteId, reactions, myReaction })

  if (reactionArray.length === 0 && !isLoggedIn) return null

  return (
    <div className="reaction-bar" role="group" aria-label="Reactions">
      {reactionArray.map(([reaction, count]) => {
        const isActive = (optimisticMyReaction ?? '') === reaction
        return (
          <button
            key={reaction}
            className="reaction-bar-btn"
            onClick={() => { if (isLoggedIn && !isReadOnly) handleReactionClick(reaction) }}
            disabled={pendingReaction !== undefined || isReadOnly}
            title={isReadOnly ? t('readonly.explanation') : isActive ? 'Remove your reaction' : `React with ${reaction}`}
            aria-label={isReadOnly ? t('readonly.explanation') : isActive ? `Remove your ${reaction} reaction` : `React with ${reaction}`}
            aria-pressed={isActive}
            type="button"
          >
            <ReactionButton reaction={reaction} count={count} reactionEmojis={reactionEmojis} />
          </button>
        )
      })}

      {isLoggedIn && !isReadOnly && (
        <button
          className="reaction-add-btn"
          onClick={() => openEmojiPicker()}
          disabled={pendingReaction !== undefined}
          title="Add reaction"
          aria-label="Add reaction"
          type="button"
        >
          +
        </button>
      )}

      {showEmojiPicker && (
        <EmojiPicker
          onSelect={handleEmojiSelect}
          onClose={closeEmojiPicker}
          reactionAcceptance={reactionAcceptance}
        />
      )}
    </div>
  )
}
