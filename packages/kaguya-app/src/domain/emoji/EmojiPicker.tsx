// SPDX-License-Identifier: MPL-2.0

import { useState, useEffect } from 'preact/hooks'
import type { ReactionAcceptance } from '../../infra/sharedTypes'
import { getAllEmojis, getCategories, lazyLoadGlobal } from './emojiStore'
import { client } from '../auth/appState'
import { t } from '../../infra/i18n'
import { proxyUrl } from '../../infra/mediaProxy'

type Props = {
  onSelect: (emoji: string) => void
  onClose: () => void
  reactionAcceptance?: ReactionAcceptance
}

const itemSize = 44
const containerHeight = 400
const itemsPerRow = 8
const overscanRows = 2

export function EmojiPicker({ onSelect, onClose, reactionAcceptance }: Props) {
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedCategory, setSelectedCategory] = useState<string | undefined>(undefined)
  const [scrollTop, setScrollTop] = useState(0)

  useEffect(() => {
    const currentClient = client.value
    if (currentClient && currentClient.backend === 'misskey') void lazyLoadGlobal(currentClient.client)
  }, [])

  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', handleEscape)
    return () => document.removeEventListener('keydown', handleEscape)
  }, [onClose])

  useEffect(() => {
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => { document.body.style.overflow = prev }
  }, [])

  const isLikeOnly = reactionAcceptance === 'likeOnly'
  const allEmojis = getAllEmojis()
  const categories = getCategories()

  const filteredEmojis = allEmojis.filter(emoji => {
    if (isLikeOnly) return emoji.name.includes('heart') || emoji.name.includes('like')
    const matchesCategory = !selectedCategory || (emoji.category ?? 'Other') === selectedCategory
    const matchesSearch = !searchQuery ||
      emoji.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      emoji.aliases.some(a => a.toLowerCase().includes(searchQuery.toLowerCase()))
    return matchesCategory && matchesSearch
  })

  const totalItems = filteredEmojis.length
  const totalRows = Math.ceil(totalItems / itemsPerRow)
  const startRow = Math.max(Math.floor(scrollTop / itemSize) - overscanRows, 0)
  const endRow = Math.min(Math.ceil((scrollTop + containerHeight) / itemSize) + overscanRows, totalRows)
  const visibleEmojis = filteredEmojis.slice(startRow * itemsPerRow, Math.min(endRow * itemsPerRow, totalItems))

  return (
    <div
      class="emoji-picker-overlay"
      onClick={() => onClose()}
      role="dialog"
      aria-modal={true}
      aria-label={t('emoji.picker')}
    >
      <div class="emoji-picker-modal" onClick={e => e.stopPropagation()}>
        <div class="emoji-picker-header">
          <input
            class="emoji-search"
            type="text"
            placeholder={t('emoji.search_placeholder')}
            value={searchQuery}
            onInput={e => setSearchQuery((e.target as HTMLInputElement).value)}
            aria-label={t('emoji.search')}
          />
          <button class="emoji-close" onClick={() => onClose()} aria-label={t('emoji.close_picker')} type="button">
            ×
          </button>
        </div>

        {!isLikeOnly && categories.length > 1 && (
          <div class="emoji-categories" role="tablist">
            <button
              class={!selectedCategory ? 'emoji-category-tab active' : 'emoji-category-tab'}
              onClick={() => setSelectedCategory(undefined)}
              role="tab"
              aria-selected={!selectedCategory}
              type="button"
            >
              {t('emoji.all')}
            </button>
            {categories.map(cat => (
              <button
                key={cat}
                class={selectedCategory === cat ? 'emoji-category-tab active' : 'emoji-category-tab'}
                onClick={() => setSelectedCategory(cat)}
                role="tab"
                aria-selected={selectedCategory === cat}
                type="button"
              >
                {cat}
              </button>
            ))}
          </div>
        )}

        <div
          class="emoji-grid"
          role="grid"
          aria-label={t('emoji.list')}
          onScroll={e => setScrollTop((e.target as HTMLElement).scrollTop)}
        >
          {filteredEmojis.length === 0 ? (
            <div class="emoji-empty" role="status">
              <p>{t('emoji.not_found')}</p>
            </div>
          ) : (
            <div class="emoji-grid-content" style={{ height: `${totalRows * itemSize}px`, position: 'relative' }}>
              <div class="emoji-grid-items" style={{ transform: `translateY(${startRow * itemSize}px)` }}>
                {visibleEmojis.map(emoji => (
                  <button
                    key={emoji.name}
                    class="emoji-item"
                    onClick={() => { onSelect(`:${emoji.name}:`); onClose() }}
                    title={emoji.name}
                    aria-label={`${emoji.name}${t('emoji.select')}`}
                    type="button"
                  >
                    <img src={proxyUrl(emoji.url)} alt={`:${emoji.name}:`} />
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
