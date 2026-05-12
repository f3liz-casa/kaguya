<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of Note.tsx. Thin dispatch wrapper: NoteViewComponent
  accepts a decoded NoteView directly, while the (rare) Note variant
  takes an unknown payload and runs it through the decoder first.

  Both default to rendering through NoteCard.svelte. Not yet mounted
  at runtime — Note.tsx remains the live component until M5 mount
  swap.

  Note that Svelte components can't co-export multiple named values
  the way Preact's `NoteViewComponent` / `Note` do; consumers pick
  via the `decode` prop (true → run noteDecoder, false → use as-is).
-->

<script lang="ts">
  import type { NoteView } from '../../../domain/note/noteView'
  import { decode } from '../../../domain/note/noteDecoder'
  import NoteCard from './NoteCard.svelte'

  type Props =
    | { note: NoteView; noteHost?: string; decode?: false }
    | { note: unknown; decode: true }
  let props: Props = $props()

  const decoded = $derived.by<NoteView | null>(() => {
    if ('decode' in props && props.decode) {
      return decode(props.note)
    }
    return (props as { note: NoteView }).note
  })

  const noteHost = $derived('noteHost' in props ? props.noteHost : undefined)
</script>

{#if decoded}
  <NoteCard note={decoded} {noteHost} />
{/if}
