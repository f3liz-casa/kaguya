// SPDX-License-Identifier: MPL-2.0

import { useState, useEffect } from 'preact/hooks'
import { client, isLoggedIn } from '../domain/auth/appState'
import { isReadOnlyMode } from '../domain/auth/appState'
import * as Backend from '../lib/backend'
import { showError } from './toastState'

export type ReactionBarHookResult = {
  pendingReaction: string | undefined
  showEmojiPicker: boolean
  reactionArray: [string, number][]
  optimisticMyReaction: string | undefined
  isLoggedIn: boolean
  isReadOnly: boolean
  handleReactionClick: (reaction: string) => void
  handleEmojiSelect: (emoji: string) => void
  openEmojiPicker: () => void
  closeEmojiPicker: () => void
}

export function useReactionBar(opts: {
  noteId: string
  reactions: Record<string, number>
  myReaction: string | undefined
}): ReactionBarHookResult {
  const { noteId, reactions, myReaction } = opts

  const [pendingReaction, setPendingReaction] = useState<string | undefined>(undefined)
  const [showEmojiPicker, setShowEmojiPicker] = useState(false)
  const [optimisticReactions, setOptimisticReactions] = useState(reactions)
  const [optimisticMyReaction, setOptimisticMyReaction] = useState(myReaction)

  useEffect(() => { setOptimisticReactions(reactions) }, [reactions, noteId])
  useEffect(() => { setOptimisticMyReaction(myReaction) }, [myReaction, noteId])

  function handleReactionClick(reaction: string) {
    void (async () => {
      const currentClient = client.value
      const loggedIn = isLoggedIn.value
      const readOnly = isReadOnlyMode()

      if (readOnly) {
        showError("Cannot react: You're in read-only mode")
        return
      }
      if (pendingReaction !== undefined || !loggedIn || !currentClient) return

      setPendingReaction(reaction)
      const shouldRemove = (optimisticMyReaction ?? '') === reaction

      if (shouldRemove) {
        setOptimisticMyReaction(undefined)
        setOptimisticReactions(prev => {
          const next = { ...prev }
          const newCount = (next[reaction] ?? 1) - 1
          if (newCount > 0) next[reaction] = newCount
          else delete next[reaction]
          return next
        })

        const result = await Backend.unreact(currentClient, noteId)
        if (result.ok) {
          setPendingReaction(undefined)
        } else {
          showError(`Failed to remove reaction: ${result.error}`)
          setOptimisticMyReaction(myReaction)
          setOptimisticReactions(reactions)
          setPendingReaction(undefined)
        }
      } else {
        const oldReaction = optimisticMyReaction
        setOptimisticMyReaction(reaction)
        setOptimisticReactions(prev => {
          const next = { ...prev }
          next[reaction] = (next[reaction] ?? 0) + 1
          if (oldReaction) {
            const oldCount = (next[oldReaction] ?? 1) - 1
            if (oldCount > 0) next[oldReaction] = oldCount
            else delete next[oldReaction]
          }
          return next
        })

        const result = await Backend.react(currentClient, noteId, reaction)
        if (result.ok) {
          setPendingReaction(undefined)
        } else {
          showError(`Failed to add reaction: ${result.error}`)
          setOptimisticMyReaction(myReaction)
          setOptimisticReactions(reactions)
          setPendingReaction(undefined)
        }
      }
    })()
  }

  const reactionArray = Object.entries(optimisticReactions)
    .sort(([, a], [, b]) => b - a) as [string, number][]

  return {
    pendingReaction,
    showEmojiPicker,
    reactionArray,
    optimisticMyReaction,
    isLoggedIn: isLoggedIn.value,
    isReadOnly: isReadOnlyMode(),
    handleReactionClick,
    handleEmojiSelect: handleReactionClick,
    openEmojiPicker: () => setShowEmojiPicker(true),
    closeEmojiPicker: () => setShowEmojiPicker(false),
  }
}
