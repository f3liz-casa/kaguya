// SPDX-License-Identifier: MPL-2.0
//
// Drop-in replacement for MfmRenderer. Dispatches to the correct parser
// by contentType, memoizes the IR, renders with SocialRenderer.

import { useMemo } from 'preact/hooks'
import type { ContentType } from '../../domain/note/noteView'
import type { BlueskyFacet } from './fromFacets'
import type { FetchPriority } from './emojiComponents'
import { fromMfm } from './fromMfm'
import { fromHtml } from './fromHtml'
import { fromFacets } from './fromFacets'
import { SocialRenderer } from './SocialRenderer'
import { instanceName } from '../../domain/auth/appState'
import * as mfm from 'mfm-js'

type Props = {
  text: string
  contentType?: ContentType
  parseSimple?: boolean
  contextHost?: string
  facets?: BlueskyFacet[]
}

export function ContentRenderer({
  text,
  contentType = 'mfm',
  parseSimple = false,
  contextHost,
  facets,
}: Props) {
  const localHost = instanceName.value
  const ctxHost = contextHost ?? localHost
  const priority: FetchPriority = parseSimple ? 3 : 1

  const nodes = useMemo(() => {
    switch (contentType) {
      case 'mfm': {
        const parsed = parseSimple ? mfm.parseSimple(text) : mfm.parse(text)
        return fromMfm(parsed as Parameters<typeof fromMfm>[0])
      }
      case 'html':
        return fromHtml(text)
      case 'bluesky':
        return fromFacets(text, facets ?? [])
    }
  }, [text, contentType, parseSimple, facets])

  const Tag = parseSimple ? 'span' : 'div'

  return (
    <Tag class="mfm-content">
      <SocialRenderer nodes={nodes} contextHost={ctxHost} priority={priority} />
    </Tag>
  )
}
