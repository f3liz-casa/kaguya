// SPDX-License-Identifier: MPL-2.0
//
// Transform Bluesky text + facets → SocialNode[].
// Facet byte offsets are UTF-8, not JS string indices.

import type { SocialNode, SocialInline } from './socialNode'

export type BlueskyFeature =
  | { $type: 'app.bsky.richtext.facet#mention'; did: string }
  | { $type: 'app.bsky.richtext.facet#link'; uri: string }
  | { $type: 'app.bsky.richtext.facet#tag'; tag: string }

export type BlueskyFacet = {
  index: { byteStart: number; byteEnd: number }
  features: BlueskyFeature[]
}

const encoder = new TextEncoder()
const decoder = new TextDecoder()

function decodeSlice(bytes: Uint8Array, start: number, end: number): string {
  return decoder.decode(bytes.slice(start, end))
}

function featureToInline(feature: BlueskyFeature, text: string): SocialInline {
  switch (feature.$type) {
    case 'app.bsky.richtext.facet#mention': {
      const username = text.startsWith('@') ? text.slice(1) : text
      return { type: 'mention', username, host: null }
    }
    case 'app.bsky.richtext.facet#link':
      return { type: 'link', url: feature.uri, children: [{ type: 'text', value: text }] }
    case 'app.bsky.richtext.facet#tag':
      return { type: 'hashtag', tag: feature.tag }
  }
}

function textToInlines(text: string): SocialInline[] {
  const parts = text.split('\n')
  const result: SocialInline[] = []
  for (let i = 0; i < parts.length; i++) {
    if (i > 0) result.push({ type: 'break' })
    if (parts[i]) result.push({ type: 'text', value: parts[i] })
  }
  return result
}

export function fromFacets(text: string, facets: BlueskyFacet[]): SocialNode[] {
  if (!text) return []

  const bytes = encoder.encode(text)
  const sorted = [...facets].sort((a, b) => a.index.byteStart - b.index.byteStart)

  const inlines: SocialInline[] = []
  let cursor = 0

  for (const facet of sorted) {
    const { byteStart, byteEnd } = facet.index
    if (byteStart < cursor) continue

    if (byteStart > cursor) {
      inlines.push(...textToInlines(decodeSlice(bytes, cursor, byteStart)))
    }

    const facetText = decodeSlice(bytes, byteStart, byteEnd)
    const feature = facet.features[0]
    if (feature) {
      inlines.push(featureToInline(feature, facetText))
    } else {
      inlines.push({ type: 'text', value: facetText })
    }

    cursor = byteEnd
  }

  if (cursor < bytes.length) {
    inlines.push(...textToInlines(decodeSlice(bytes, cursor, bytes.length)))
  }

  return [{ type: 'paragraph', children: inlines }]
}
