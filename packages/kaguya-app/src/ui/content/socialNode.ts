// SPDX-License-Identifier: MPL-2.0
//
// Unified content IR for social media posts. Follows mdast naming conventions
// and unist structure (every node has `type`, parent nodes have `children`,
// leaf nodes carry data in top-level fields).
//
// Compatible with unist-util-visit and other ecosystem tools without
// requiring them at runtime.

// ─── Block nodes ─────────────────────────────────────────────────────────────

export type SocialParagraph  = { type: 'paragraph';  children: SocialInline[] }
export type SocialBlockquote = { type: 'blockquote'; children: SocialNode[] }
export type SocialCode       = { type: 'code';       value: string; lang?: string }
export type SocialCenter     = { type: 'center';     children: SocialInline[] }
export type SocialMathBlock  = { type: 'mathBlock';  value: string }
export type SocialSearch     = { type: 'search';     query: string }

export type SocialBlock =
  | SocialParagraph
  | SocialBlockquote
  | SocialCode
  | SocialCenter
  | SocialMathBlock
  | SocialSearch

// ─── Inline nodes ────────────────────────────────────────────────────────────

export type SocialText         = { type: 'text';         value: string }
export type SocialBreak        = { type: 'break' }
export type SocialStrong       = { type: 'strong';       children: SocialInline[] }
export type SocialEmphasis     = { type: 'emphasis';     children: SocialInline[] }
export type SocialDelete       = { type: 'delete';       children: SocialInline[] }
export type SocialSmall        = { type: 'small';        children: SocialInline[] }
export type SocialInlineCode   = { type: 'inlineCode';   value: string }
export type SocialInlineMath   = { type: 'inlineMath';   value: string }
export type SocialLink         = { type: 'link';         url: string; silent?: boolean; children: SocialInline[] }
export type SocialMention      = { type: 'mention';      username: string; host: string | null }
export type SocialHashtag      = { type: 'hashtag';      tag: string }
export type SocialEmoji        = { type: 'emoji';        name: string }
export type SocialUnicodeEmoji = { type: 'unicodeEmoji'; value: string }
export type SocialMfmFn        = { type: 'mfmFn';       name: string; args: Record<string, string | true>; children: SocialInline[] }
export type SocialPlain        = { type: 'plain';        children: SocialInline[] }

export type SocialInline =
  | SocialText
  | SocialBreak
  | SocialStrong
  | SocialEmphasis
  | SocialDelete
  | SocialSmall
  | SocialInlineCode
  | SocialInlineMath
  | SocialLink
  | SocialMention
  | SocialHashtag
  | SocialEmoji
  | SocialUnicodeEmoji
  | SocialMfmFn
  | SocialPlain

// ─── Union ───────────────────────────────────────────────────────────────────

export type SocialNode = SocialBlock | SocialInline
