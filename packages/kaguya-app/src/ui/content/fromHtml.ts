// SPDX-License-Identifier: MPL-2.0
//
// Transform Mastodon HTML → SocialNode[] using browser-native DOMParser.
// Pattern-matches Mastodon's known HTML structures for mentions, hashtags,
// links, and custom emoji. Unknown elements are safely unwrapped to children
// or text content — no dangerouslySetInnerHTML, no XSS.

import type { SocialNode, SocialInline } from './socialNode'

function hasClass(el: Element, cls: string): boolean {
  return el.classList.contains(cls)
}

function parseMentionFromHref(href: string): { username: string; host: string | null } | undefined {
  try {
    const url = new URL(href)
    const match = url.pathname.match(/^\/@([^@/]+)$/)
    if (match) return { username: match[1], host: url.hostname }
  } catch { /* ignore */ }
  return undefined
}

function parseHashtagFromHref(href: string): string | undefined {
  try {
    const url = new URL(href)
    const match = url.pathname.match(/^\/tags\/(.+)$/)
    if (match) return decodeURIComponent(match[1])
  } catch { /* ignore */ }
  return undefined
}

function extractVisibleText(anchor: Element): string {
  let text = ''
  for (const child of anchor.childNodes) {
    if (child.nodeType === 3) {
      text += child.textContent ?? ''
    } else if (child.nodeType === 1) {
      const el = child as Element
      if (!hasClass(el, 'invisible')) {
        text += el.textContent ?? ''
      }
    }
  }
  return text
}

function convertAnchor(el: Element): SocialInline {
  const href = el.getAttribute('href') ?? ''

  if (hasClass(el, 'mention') && hasClass(el, 'hashtag')) {
    const tag = parseHashtagFromHref(href)
    if (tag) return { type: 'hashtag', tag }
  }

  if (hasClass(el, 'mention') || hasClass(el, 'u-url')) {
    const mention = parseMentionFromHref(href)
    if (mention) return { type: 'mention', username: mention.username, host: mention.host }
  }

  const visibleText = extractVisibleText(el)
  return {
    type: 'link',
    url: href,
    children: [{ type: 'text', value: visibleText || href }],
  }
}

function convertEmojiImg(el: Element): SocialInline | undefined {
  const alt = el.getAttribute('alt') ?? ''
  const match = alt.match(/^:([^:]+):$/)
  if (match) return { type: 'emoji', name: match[1] }
  return undefined
}

function convertChildren(parent: Node): SocialInline[] {
  const results: SocialInline[] = []
  for (const child of parent.childNodes) {
    if (child.nodeType === 3) {
      const text = child.textContent ?? ''
      if (text) results.push({ type: 'text', value: text })
    } else if (child.nodeType === 1) {
      const el = child as Element
      const inline = convertElement(el)
      if (inline) {
        if (Array.isArray(inline)) results.push(...inline)
        else results.push(inline)
      }
    }
  }
  return results
}

function convertBlockChildren(parent: Node): SocialNode[] {
  const results: SocialNode[] = []
  for (const child of parent.childNodes) {
    if (child.nodeType === 3) {
      const text = child.textContent ?? ''
      if (text) results.push({ type: 'text', value: text })
    } else if (child.nodeType === 1) {
      const el = child as Element
      const block = convertBlockElement(el)
      if (block) results.push(block)
      else {
        const inline = convertElement(el)
        if (inline) {
          if (Array.isArray(inline)) results.push(...inline)
          else results.push(inline)
        }
      }
    }
  }
  return results
}

function convertBlockElement(el: Element): SocialNode | undefined {
  const tag = el.tagName.toLowerCase()

  switch (tag) {
    case 'p':
      return { type: 'paragraph', children: convertChildren(el) }
    case 'blockquote':
      return { type: 'blockquote', children: convertBlockChildren(el) }
    case 'pre': {
      const codeEl = el.querySelector('code')
      const value = codeEl?.textContent ?? el.textContent ?? ''
      const langClass = codeEl?.className.match(/language-(\S+)/)
      return { type: 'code', value, lang: langClass?.[1] }
    }
    default:
      return undefined
  }
}

function convertElement(el: Element): SocialInline | SocialInline[] | undefined {
  const tag = el.tagName.toLowerCase()

  switch (tag) {
    case 'br':
      return { type: 'break' }
    case 'strong':
    case 'b':
      return { type: 'strong', children: convertChildren(el) }
    case 'em':
    case 'i':
      return { type: 'emphasis', children: convertChildren(el) }
    case 'del':
    case 's':
      return { type: 'delete', children: convertChildren(el) }
    case 'code':
      return { type: 'inlineCode', value: el.textContent ?? '' }
    case 'a':
      return convertAnchor(el)
    case 'img': {
      if (hasClass(el, 'custom-emoji') || hasClass(el, 'emojione') || el.getAttribute('draggable') === 'false') {
        return convertEmojiImg(el)
      }
      return undefined
    }
    case 'span': {
      if (hasClass(el, 'invisible')) return undefined
      if (hasClass(el, 'h-card')) return convertChildren(el)
      return convertChildren(el)
    }
    default:
      return convertChildren(el)
  }
}

export function fromHtml(html: string): SocialNode[] {
  const doc = new DOMParser().parseFromString(html, 'text/html')
  const body = doc.body

  const results: SocialNode[] = []
  for (const child of body.childNodes) {
    if (child.nodeType === 1) {
      const el = child as Element
      const block = convertBlockElement(el)
      if (block) {
        results.push(block)
        continue
      }
      const inline = convertElement(el)
      if (inline) {
        if (Array.isArray(inline)) {
          results.push({ type: 'paragraph', children: inline })
        } else {
          results.push({ type: 'paragraph', children: [inline] })
        }
      }
    } else if (child.nodeType === 3) {
      const text = child.textContent?.trim()
      if (text) results.push({ type: 'paragraph', children: [{ type: 'text', value: text }] })
    }
  }

  return results
}
