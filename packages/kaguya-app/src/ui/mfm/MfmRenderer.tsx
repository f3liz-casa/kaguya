// SPDX-License-Identifier: MPL-2.0

import { useState, useEffect, useRef } from 'preact/hooks'
import type { VNode } from 'preact'
import { getEmoji, lazyLoadGlobal } from '../../domain/emoji/emojiStore'
import { instanceName, client } from '../../domain/auth/appState'
import { proxyUrl } from '../../infra/mediaProxy'
import { observeImage, unobserveImage, isLoaded as isImageLoaded } from '../../infra/fetchQueue'
import type { FetchPriority } from '../../infra/fetchQueue'
import * as mfm from 'mfm-js'
import { toTwemojiUrl } from '../content/emojiComponents'
import { Link } from '../router'

type MfmNode = ReturnType<typeof mfm.parse>[number]

/** Emoji image that uses the priority load queue with viewport detection. */
function EmojiImg({ url, name, priority }: { url: string; name: string; priority: FetchPriority }) {
  const ref = useRef<HTMLImageElement>(null)

  const proxied = proxyUrl(url)

  useEffect(() => {
    const el = ref.current
    if (!el) return
    if (isImageLoaded(proxied)) {
      el.src = proxied
    } else {
      observeImage(el, proxied, priority)
    }
    return () => { if (el) unobserveImage(el) }
  }, [proxied, priority])

  return (
    <img
      ref={ref}
      class="mfm-emoji-image"
      alt={`:${name}:`}
      title={`:${name}:`}
    />
  )
}

/** Reactive emoji code component — re-renders when emoji store updates. */
function EmojiCode({ name, priority }: { name: string; priority: FetchPriority }) {
  const emoji = getEmoji(name)
  if (emoji) {
    return <EmojiImg url={proxyUrl(emoji.url)} name={name} priority={priority} />
  }
  const currentClient = client.value
  if (currentClient && currentClient.backend === 'misskey') void lazyLoadGlobal(currentClient.client)
  return <span class="mfm-emoji-code">:{name}:</span>
}

function getPropString(props: Record<string, unknown> | null | undefined, key: string): string | undefined {
  if (!props) return undefined
  const v = props[key]
  return typeof v === 'string' ? v : undefined
}

function getPropNullableString(props: Record<string, unknown> | null | undefined, key: string): string | undefined {
  if (!props) return undefined
  const v = props[key]
  if (v === null || v === undefined) return undefined
  return typeof v === 'string' ? v : undefined
}

function hasJapanese(text: string): boolean {
  return /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF\u3400-\u4DBF]/.test(text)
}

function hasKorean(text: string): boolean {
  return /[\uAC00-\uD7AF\u1100-\u11FF]/.test(text)
}

function renderNode(node: MfmNode, key: number, contextHost: string, priority: FetchPriority): VNode | null {
  const type = node.type
  const props = (node as any).props as Record<string, unknown> | undefined

  switch (type) {
    case 'text': {
      const text = getPropString(props, 'text') ?? ''
      if (!text) return null
      if (hasJapanese(text)) {
        return (
          <span key={key} style={{ wordBreak: 'keep-all' }}>
            {text.split('').map((c, i) => i === 0 ? c : <><wbr />{c}</>)}
          </span>
        )
      }
      if (hasKorean(text)) {
        return <span key={key} style={{ wordBreak: 'keep-all' }}>{text}</span>
      }
      return <>{text}</>
    }
    case 'bold':
      return <strong key={key}>{renderChildren((node as any).children, contextHost, priority)}</strong>
    case 'italic':
      return <em key={key}>{renderChildren((node as any).children, contextHost, priority)}</em>
    case 'strike':
      return <del key={key}>{renderChildren((node as any).children, contextHost, priority)}</del>
    case 'small':
      return <small key={key}>{renderChildren((node as any).children, contextHost, priority)}</small>
    case 'inlineCode': {
      const code = getPropString(props, 'code') ?? ''
      return <code key={key}>{code}</code>
    }
    case 'blockCode': {
      const code = getPropString(props, 'code') ?? ''
      const lang = getPropNullableString(props, 'lang')
      return (
        <pre key={key} class="mfm-code-block">
          <code class={lang ? `language-${lang}` : undefined}>{code}</code>
        </pre>
      )
    }
    case 'quote':
      return <blockquote key={key} class="mfm-quote">{renderChildren((node as any).children, contextHost, priority)}</blockquote>
    case 'center':
      return <div key={key} class="mfm-center">{renderChildren((node as any).children, contextHost, priority)}</div>
    case 'url': {
      const url = getPropString(props, 'url') ?? ''
      return <a key={key} href={url} target="_blank" rel="noopener noreferrer" class="mfm-url">{url}</a>
    }
    case 'link': {
      const url = getPropString(props, 'url') ?? '#'
      const silent = !!(props?.['silent'])
      const children = renderChildren((node as any).children, contextHost, priority)
      return (
        <a key={key} href={url} target="_blank" rel="noopener noreferrer"
          class={silent ? 'mfm-link mfm-link-silent' : 'mfm-link'}>
          {children}
        </a>
      )
    }
    case 'mention': {
      const username = getPropString(props, 'username') ?? 'unknown'
      const host = getPropNullableString(props, 'host')
      const mentionHost = host ?? contextHost
      const href = `/@${username}@${mentionHost}`
      const displayAcct = mentionHost === contextHost ? `@${username}` : `@${username}@${mentionHost}`
      return <Link key={key} href={href} class="mfm-mention">{displayAcct}</Link>
    }
    case 'hashtag': {
      const tag = getPropString(props, 'hashtag') ?? ''
      return <a key={key} href={`/tags/${tag}`} class="mfm-hashtag">#{tag}</a>
    }
    case 'emojiCode': {
      const name = getPropString(props, 'name') ?? ''
      return <EmojiCode key={key} name={name} priority={priority} />
    }
    case 'unicodeEmoji': {
      const emoji = getPropString(props, 'emoji') ?? ''
      return (
        <img
          key={key}
          class="mfm-emoji"
          src={toTwemojiUrl(emoji)}
          alt={emoji}
          draggable={false}
          loading="lazy"
        />
      )
    }
    case 'mathInline': {
      const formula = getPropString(props, 'formula') ?? ''
      return <span key={key} class="mfm-math-inline">{`\\(${formula}\\)`}</span>
    }
    case 'mathBlock': {
      const formula = getPropString(props, 'formula') ?? ''
      return <div key={key} class="mfm-math-block">{`\\[${formula}\\]`}</div>
    }
    case 'search': {
      const query = getPropString(props, 'query') ?? ''
      return (
        <div key={key} class="mfm-search">
          <span>{query}</span>
          <button class="mfm-search-button">検索</button>
        </div>
      )
    }
    case 'fn': {
      const name = getPropString(props, 'name') ?? 'unknown'
      return <span key={key} class={`mfm-fn mfm-fn-${name}`}>{renderChildren((node as any).children, contextHost, priority)}</span>
    }
    case 'plain':
      return <span key={key} class="mfm-plain">{renderChildren((node as any).children, contextHost, priority)}</span>
    default:
      return null
  }
}

function renderChildren(children: MfmNode[] | undefined, contextHost: string, priority: FetchPriority): VNode[] {
  if (!children) return []
  return children.map((child, i) => renderNode(child, i, contextHost, priority)).filter(Boolean) as VNode[]
}

type Props = {
  text: string
  parseSimple?: boolean
  contextHost?: string
}

export function MfmRenderer({ text, parseSimple = false, contextHost }: Props) {
  const localHost = instanceName.value
  const ctxHost = contextHost ?? localHost

  // P1 for note text inline emoji, P3 for display-name / bio emoji (parseSimple)
  const priority: FetchPriority = parseSimple ? 3 : 1

  const [nodes, setNodes] = useState<MfmNode[] | undefined>(undefined)

  useEffect(() => {
    const parsed = parseSimple ? mfm.parseSimple(text) : mfm.parse(text)
    setNodes(parsed as MfmNode[])
  }, [text, parseSimple])

  if (!nodes) return null

  if (parseSimple) {
    return (
      <span class="mfm-content">
        {nodes.map((node, i) => renderNode(node, i, ctxHost, priority))}
      </span>
    )
  }

  return (
    <div class="mfm-content">
      {nodes.map((node, i) => renderNode(node, i, ctxHost, priority))}
    </div>
  )
}
