// SPDX-License-Identifier: MPL-2.0
//
// Unified renderer: SocialNode[] → Preact VNodes.
// Direct port of MfmRenderer's renderNode logic, operating on SocialNode.

import type { VNode } from 'preact'
import type { SocialNode, SocialInline } from './socialNode'
import {
  EmojiCode, EmojiImg, toTwemojiUrl, hasJapanese, hasKorean,
} from './emojiComponents'
import type { FetchPriority } from './emojiComponents'
import { proxyUrl } from '../../infra/mediaProxy'
import { Link } from '../router'

function renderInline(node: SocialInline, key: number, contextHost: string, priority: FetchPriority): VNode | null {
  switch (node.type) {
    case 'text': {
      const { value } = node
      if (!value) return null
      if (hasJapanese(value)) {
        return (
          <span key={key} style={{ wordBreak: 'keep-all' }}>
            {value.split('').map((c, i) => i === 0 ? c : <><wbr />{c}</>)}
          </span>
        )
      }
      if (hasKorean(value)) {
        return <span key={key} style={{ wordBreak: 'keep-all' }}>{value}</span>
      }
      return <>{value}</>
    }
    case 'break':
      return <br key={key} />
    case 'strong':
      return <strong key={key}>{renderInlines(node.children, contextHost, priority)}</strong>
    case 'emphasis':
      return <em key={key}>{renderInlines(node.children, contextHost, priority)}</em>
    case 'delete':
      return <del key={key}>{renderInlines(node.children, contextHost, priority)}</del>
    case 'small':
      return <small key={key}>{renderInlines(node.children, contextHost, priority)}</small>
    case 'inlineCode':
      return <code key={key}>{node.value}</code>
    case 'inlineMath':
      return <span key={key} class="mfm-math-inline">{`\\(${node.value}\\)`}</span>
    case 'link': {
      const children = renderInlines(node.children, contextHost, priority)
      return (
        <a key={key} href={node.url} target="_blank" rel="noopener noreferrer"
          class={node.silent ? 'mfm-link mfm-link-silent' : 'mfm-link'}>
          {children}
        </a>
      )
    }
    case 'mention': {
      const mentionHost = node.host ?? contextHost
      const href = `/@${node.username}@${mentionHost}`
      const display = mentionHost === contextHost ? `@${node.username}` : `@${node.username}@${mentionHost}`
      return <Link key={key} href={href} class="mfm-mention">{display}</Link>
    }
    case 'hashtag':
      return <a key={key} href={`/tags/${node.tag}`} class="mfm-hashtag">#{node.tag}</a>
    case 'emoji':
      return <EmojiCode key={key} name={node.name} priority={priority} />
    case 'unicodeEmoji':
      return (
        <img
          key={key}
          class="mfm-emoji"
          src={toTwemojiUrl(node.value)}
          alt={node.value}
          draggable={false}
          loading="lazy"
        />
      )
    case 'mfmFn':
      return <span key={key} class={`mfm-fn mfm-fn-${node.name}`}>{renderInlines(node.children, contextHost, priority)}</span>
    case 'plain':
      return <span key={key} class="mfm-plain">{renderInlines(node.children, contextHost, priority)}</span>
    default:
      return null
  }
}

function renderInlines(nodes: SocialInline[], contextHost: string, priority: FetchPriority): VNode[] {
  return nodes.map((n, i) => renderInline(n, i, contextHost, priority)).filter(Boolean) as VNode[]
}

function renderNode(node: SocialNode, key: number, contextHost: string, priority: FetchPriority): VNode | null {
  switch (node.type) {
    case 'paragraph':
      return <p key={key}>{renderInlines(node.children, contextHost, priority)}</p>
    case 'blockquote':
      return <blockquote key={key} class="mfm-quote">{renderNodes(node.children, contextHost, priority)}</blockquote>
    case 'code': {
      return (
        <pre key={key} class="mfm-code-block">
          <code class={node.lang ? `language-${node.lang}` : undefined}>{node.value}</code>
        </pre>
      )
    }
    case 'center':
      return <div key={key} class="mfm-center">{renderInlines(node.children, contextHost, priority)}</div>
    case 'mathBlock':
      return <div key={key} class="mfm-math-block">{`\\[${node.value}\\]`}</div>
    case 'search':
      return (
        <div key={key} class="mfm-search">
          <span>{node.query}</span>
          <button class="mfm-search-button">検索</button>
        </div>
      )
    default:
      return renderInline(node as SocialInline, key, contextHost, priority)
  }
}

function renderNodes(nodes: SocialNode[], contextHost: string, priority: FetchPriority): VNode[] {
  return nodes.map((n, i) => renderNode(n, i, contextHost, priority)).filter(Boolean) as VNode[]
}

type Props = {
  nodes: SocialNode[]
  contextHost: string
  priority: FetchPriority
}

export function SocialRenderer({ nodes, contextHost, priority }: Props) {
  return <>{renderNodes(nodes, contextHost, priority)}</>
}
