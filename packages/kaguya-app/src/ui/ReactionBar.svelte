<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of ReactionBar.tsx + reactionBarHook.ts (inlined). Shows
  the reactions on a note as buttons + add-reaction trigger that opens
  EmojiPicker. Optimistic local update on click, rolled back on
  backend failure.

  Not yet mounted at runtime; the Preact ReactionBar.tsx remains live
  until M5 mount swap.

  Hard-coded English in titles/aria-labels carried over verbatim
  (`React with X` / `Remove your reaction` / `Add reaction` /
  `Cannot react: You're in read-only mode` / `Failed to ...`),
  matching the Preact original — coto's PR-b audit retains them.
-->

<script lang="ts">
  import type { ReactionAcceptance } from '../infra/sharedTypes'
  import { client, isLoggedIn, isReadOnlyMode } from '../domain/auth/appState'
  import * as Backend from '../lib/backend'
  import { showError } from './toastState'
  import { currentLocale, t } from '../infra/i18n'
  import ReactionButton from './ReactionButton.svelte'
  import EmojiPicker from '../domain/emoji/EmojiPicker.svelte'
  import { svelteSignal } from './svelteSignal.svelte'

  type Props = {
    noteId: string
    reactions: Record<string, number>
    reactionEmojis: Record<string, string>
    myReaction: string | undefined
    reactionAcceptance: ReactionAcceptance | undefined
  }
  let { noteId, reactions, reactionEmojis, myReaction, reactionAcceptance }: Props = $props()

  const localeR = svelteSignal(currentLocale)
  const loggedInR = svelteSignal(isLoggedIn)

  let pendingReaction = $state<string | undefined>(undefined)
  let showEmojiPicker = $state(false)
  let optimisticReactions = $state<Record<string, number>>(reactions)
  let optimisticMyReaction = $state<string | undefined>(myReaction)

  // Sync optimistic state with prop changes (mirror of
  // useEffect[reactions, noteId] / useEffect[myReaction, noteId]).
  $effect(() => {
    void noteId
    optimisticReactions = reactions
  })
  $effect(() => {
    void noteId
    optimisticMyReaction = myReaction
  })

  const readOnly = $derived((loggedInR.value, isReadOnlyMode()))

  const reactionArray = $derived(
    (Object.entries(optimisticReactions) as [string, number][])
      .sort(([, a], [, b]) => b - a),
  )

  const L = $derived((localeR.value, {
    readonlyExplanation: t('readonly.explanation'),
  }))

  function handleReactionClick(reaction: string) {
    void (async () => {
      const currentClient = client.peek()
      const loggedIn = loggedInR.value
      const isReadOnly = readOnly

      if (isReadOnly) {
        showError("Cannot react: You're in read-only mode")
        return
      }
      if (pendingReaction !== undefined || !loggedIn || !currentClient) return

      pendingReaction = reaction
      const shouldRemove = (optimisticMyReaction ?? '') === reaction

      if (shouldRemove) {
        optimisticMyReaction = undefined
        const next = { ...optimisticReactions }
        const newCount = (next[reaction] ?? 1) - 1
        if (newCount > 0) next[reaction] = newCount
        else delete next[reaction]
        optimisticReactions = next

        const result = await Backend.unreact(currentClient, noteId)
        if (result.ok) {
          pendingReaction = undefined
        } else {
          showError(`Failed to remove reaction: ${result.error}`)
          optimisticMyReaction = myReaction
          optimisticReactions = reactions
          pendingReaction = undefined
        }
      } else {
        const oldReaction = optimisticMyReaction
        optimisticMyReaction = reaction
        const next = { ...optimisticReactions }
        next[reaction] = (next[reaction] ?? 0) + 1
        if (oldReaction) {
          const oldCount = (next[oldReaction] ?? 1) - 1
          if (oldCount > 0) next[oldReaction] = oldCount
          else delete next[oldReaction]
        }
        optimisticReactions = next

        const result = await Backend.react(currentClient, noteId, reaction)
        if (result.ok) {
          pendingReaction = undefined
        } else {
          showError(`Failed to add reaction: ${result.error}`)
          optimisticMyReaction = myReaction
          optimisticReactions = reactions
          pendingReaction = undefined
        }
      }
    })()
  }
</script>

{#if reactionArray.length > 0 || loggedInR.value}
  <div class="reaction-bar" role="group" aria-label="Reactions">
    {#each reactionArray as [reaction, count] (reaction)}
      {@const isActive = (optimisticMyReaction ?? '') === reaction}
      <button
        class="reaction-bar-btn"
        type="button"
        disabled={pendingReaction !== undefined || readOnly}
        title={readOnly ? L.readonlyExplanation : isActive ? 'Remove your reaction' : `React with ${reaction}`}
        aria-label={readOnly ? L.readonlyExplanation : isActive ? `Remove your ${reaction} reaction` : `React with ${reaction}`}
        aria-pressed={isActive}
        onclick={() => { if (loggedInR.value && !readOnly) handleReactionClick(reaction) }}
      >
        <ReactionButton {reaction} {count} {reactionEmojis} />
      </button>
    {/each}

    {#if loggedInR.value && !readOnly}
      <button
        class="reaction-add-btn"
        type="button"
        disabled={pendingReaction !== undefined}
        title="Add reaction"
        aria-label="Add reaction"
        onclick={() => { showEmojiPicker = true }}
      >
        +
      </button>
    {/if}

    {#if showEmojiPicker}
      <EmojiPicker
        onSelect={(emoji) => { showEmojiPicker = false; handleReactionClick(emoji) }}
        onClose={() => { showEmojiPicker = false }}
        {reactionAcceptance}
      />
    {/if}
  </div>
{/if}
