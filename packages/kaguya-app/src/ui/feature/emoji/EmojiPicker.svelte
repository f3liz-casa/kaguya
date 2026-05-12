<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of EmojiPicker.tsx. Searchable / category-tabbed
  modal grid with virtual-scroll windowing. Used by NoteActions.svelte
  for adding reactions. Not yet mounted at runtime.
-->

<script lang="ts">
  import type { ReactionAcceptance } from '../../../infra/sharedTypes'
  import { getAllEmojis, getCategories, lazyLoadGlobal } from '../../../domain/emoji/emojiStore'
  import { client } from '../../../domain/auth/appState'
  import { currentLocale, t } from '../../../infra/i18n'
  import { proxyUrl } from '../../../infra/mediaProxy'
  import { svelteSignal } from '../../svelteSignal.svelte'
  import { escapeKey, scrollLock, outsideClick } from '../../modalActions'

  type Props = {
    onSelect: (emoji: string) => void
    onClose: () => void
    reactionAcceptance?: ReactionAcceptance
  }
  let { onSelect, onClose, reactionAcceptance }: Props = $props()

  const itemSize = 44
  const containerHeight = 400
  const itemsPerRow = 8
  const overscanRows = 2

  const localeR = svelteSignal(currentLocale)

  let searchQuery = $state('')
  let selectedCategory = $state<string | undefined>(undefined)
  let scrollTop = $state(0)

  $effect(() => {
    const currentClient = client.peek()
    if (currentClient && currentClient.backend === 'misskey') void lazyLoadGlobal(currentClient.client)
  })

  const isLikeOnly = $derived(reactionAcceptance === 'likeOnly')
  const allEmojis = $derived(getAllEmojis())
  const categories = $derived(getCategories())

  const filteredEmojis = $derived.by(() => {
    const q = searchQuery.toLowerCase()
    return allEmojis.filter((emoji) => {
      if (isLikeOnly) return emoji.name.includes('heart') || emoji.name.includes('like')
      const matchesCategory = !selectedCategory || (emoji.category ?? 'Other') === selectedCategory
      const matchesSearch =
        !searchQuery ||
        emoji.name.toLowerCase().includes(q) ||
        emoji.aliases.some((a) => a.toLowerCase().includes(q))
      return matchesCategory && matchesSearch
    })
  })

  const totalItems = $derived(filteredEmojis.length)
  const totalRows = $derived(Math.ceil(totalItems / itemsPerRow))
  const startRow = $derived(Math.max(Math.floor(scrollTop / itemSize) - overscanRows, 0))
  const endRow = $derived(Math.min(Math.ceil((scrollTop + containerHeight) / itemSize) + overscanRows, totalRows))
  const visibleEmojis = $derived(filteredEmojis.slice(startRow * itemsPerRow, Math.min(endRow * itemsPerRow, totalItems)))

  const L = $derived((localeR.value, {
    picker: t('emoji.picker'),
    searchPlaceholder: t('emoji.search_placeholder'),
    search: t('emoji.search'),
    closePicker: t('emoji.close_picker'),
    all: t('emoji.all'),
    list: t('emoji.list'),
    notFound: t('emoji.not_found'),
    select: t('emoji.select'),
  }))
</script>

<div
  class="emoji-picker-overlay"
  role="dialog"
  aria-modal="true"
  aria-label={L.picker}
  use:scrollLock
>
  <div
    class="emoji-picker-modal"
    role="presentation"
    use:escapeKey={onClose}
    use:outsideClick={onClose}
  >
    <div class="emoji-picker-header">
      <input
        class="emoji-search"
        type="text"
        placeholder={L.searchPlaceholder}
        value={searchQuery}
        oninput={(e) => { searchQuery = (e.currentTarget as HTMLInputElement).value }}
        aria-label={L.search}
      />
      <button class="emoji-close" type="button" aria-label={L.closePicker} onclick={() => onClose()}>×</button>
    </div>

    {#if !isLikeOnly && categories.length > 1}
      <div class="emoji-categories" role="tablist">
        <button
          class={!selectedCategory ? 'emoji-category-tab active' : 'emoji-category-tab'}
          type="button"
          role="tab"
          aria-selected={!selectedCategory}
          onclick={() => { selectedCategory = undefined }}
        >
          {L.all}
        </button>
        {#each categories as cat (cat)}
          <button
            class={selectedCategory === cat ? 'emoji-category-tab active' : 'emoji-category-tab'}
            type="button"
            role="tab"
            aria-selected={selectedCategory === cat}
            onclick={() => { selectedCategory = cat }}
          >
            {cat}
          </button>
        {/each}
      </div>
    {/if}

    <div
      class="emoji-grid"
      role="grid"
      aria-label={L.list}
      onscroll={(e) => { scrollTop = (e.currentTarget as HTMLElement).scrollTop }}
    >
      {#if filteredEmojis.length === 0}
        <div class="emoji-empty" role="status">
          <p>{L.notFound}</p>
        </div>
      {:else}
        <div class="emoji-grid-content" style="height: {totalRows * itemSize}px; position: relative">
          <div class="emoji-grid-items" style="transform: translateY({startRow * itemSize}px)">
            {#each visibleEmojis as emoji (emoji.name)}
              <button
                class="emoji-item"
                type="button"
                title={emoji.name}
                aria-label={`${emoji.name}${L.select}`}
                onclick={() => { onSelect(`:${emoji.name}:`); onClose() }}
              >
                <img src={proxyUrl(emoji.url)} alt={`:${emoji.name}:`} />
              </button>
            {/each}
          </div>
        </div>
      {/if}
    </div>
  </div>
</div>
