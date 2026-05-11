// SPDX-License-Identifier: MPL-2.0
//
// Transform mfm-js AST → SocialNode[]. Pure synchronous function.

import type { SocialNode, SocialInline } from './socialNode'

type MfmNode = {
  type: string
  props?: Record<string, unknown>
  children?: MfmNode[]
}

function str(props: Record<string, unknown> | undefined, key: string): string {
  const v = props?.[key]
  return typeof v === 'string' ? v : ''
}

function nullableStr(props: Record<string, unknown> | undefined, key: string): string | null {
  const v = props?.[key]
  if (v === null || v === undefined) return null
  return typeof v === 'string' ? v : null
}

function convertInline(nodes: MfmNode[]): SocialInline[] {
  return nodes.flatMap(n => {
    const result = convertNode(n)
    return result ? [result as SocialInline] : []
  })
}

function convertNode(node: MfmNode): SocialNode | undefined {
  const { type, props, children } = node

  switch (type) {
    case 'text': {
      const value = str(props, 'text')
      return value ? { type: 'text', value } : undefined
    }
    case 'bold':
      return { type: 'strong', children: convertInline(children ?? []) }
    case 'italic':
      return { type: 'emphasis', children: convertInline(children ?? []) }
    case 'strike':
      return { type: 'delete', children: convertInline(children ?? []) }
    case 'small':
      return { type: 'small', children: convertInline(children ?? []) }
    case 'inlineCode':
      return { type: 'inlineCode', value: str(props, 'code') }
    case 'blockCode':
      return { type: 'code', value: str(props, 'code'), lang: nullableStr(props, 'lang') ?? undefined }
    case 'quote':
      return { type: 'blockquote', children: fromMfm(children ?? []) }
    case 'center':
      return { type: 'center', children: convertInline(children ?? []) }
    case 'url': {
      const url = str(props, 'url')
      return { type: 'link', url, children: [{ type: 'text', value: url }] }
    }
    case 'link': {
      const url = str(props, 'url')
      const silent = !!(props?.['silent'])
      return { type: 'link', url, silent: silent || undefined, children: convertInline(children ?? []) }
    }
    case 'mention': {
      const username = str(props, 'username')
      const host = nullableStr(props, 'host')
      return { type: 'mention', username, host }
    }
    case 'hashtag':
      return { type: 'hashtag', tag: str(props, 'hashtag') }
    case 'emojiCode':
      return { type: 'emoji', name: str(props, 'name') }
    case 'unicodeEmoji':
      return { type: 'unicodeEmoji', value: str(props, 'emoji') }
    case 'mathInline':
      return { type: 'inlineMath', value: str(props, 'formula') }
    case 'mathBlock':
      return { type: 'mathBlock', value: str(props, 'formula') }
    case 'search':
      return { type: 'search', query: str(props, 'query') }
    case 'fn': {
      const name = str(props, 'name')
      const rawArgs = props?.['args']
      const args: Record<string, string | true> = {}
      if (rawArgs && typeof rawArgs === 'object' && !Array.isArray(rawArgs)) {
        for (const [k, v] of Object.entries(rawArgs as Record<string, unknown>)) {
          args[k] = typeof v === 'string' ? v : true
        }
      }
      return { type: 'mfmFn', name, args, children: convertInline(children ?? []) }
    }
    case 'plain':
      return { type: 'plain', children: convertInline(children ?? []) }
    default:
      return undefined
  }
}

export function fromMfm(nodes: MfmNode[]): SocialNode[] {
  return nodes.flatMap(n => {
    const result = convertNode(n)
    return result ? [result] : []
  })
}
