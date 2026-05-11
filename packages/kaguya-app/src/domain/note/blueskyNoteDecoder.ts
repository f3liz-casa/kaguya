// SPDX-License-Identifier: MPL-2.0

import type { NoteView } from './noteView'
import type { UserView } from '../user/userView'
import type { FileView } from '../file/fileView'
import type { BlueskyFacet } from '../../ui/content/fromFacets'
import { asObj, getString } from '../../infra/jsonUtils'

function decodeAuthor(json: unknown): UserView | undefined {
  const obj = asObj(json)
  if (!obj) return undefined
  const did = getString(obj, 'did')
  const handle = getString(obj, 'handle')
  if (!did || !handle) return undefined
  return {
    id: did,
    name: getString(obj, 'displayName') || handle,
    username: handle,
    avatarUrl: getString(obj, 'avatar') ?? '',
    host: undefined,
  }
}

function decodeImages(embed: Record<string, unknown>): FileView[] {
  // app.bsky.embed.images#view
  if (embed['$type'] === 'app.bsky.embed.images#view') {
    const images = embed['images']
    if (!Array.isArray(images)) return []
    return images.flatMap((img, i) => {
      const o = asObj(img)
      if (!o) return []
      const thumb = getString(o, 'thumb')
      const fullsize = getString(o, 'fullsize')
      if (!thumb && !fullsize) return []
      const aspectRatio = asObj(o['aspectRatio'])
      return [{
        id: `img-${i}`,
        name: getString(o, 'alt') ?? '',
        url: fullsize ?? thumb!,
        thumbnailUrl: thumb ?? undefined,
        type: 'image/jpeg',
        isSensitive: false,
        width: aspectRatio && typeof aspectRatio['width'] === 'number' ? aspectRatio['width'] : undefined,
        height: aspectRatio && typeof aspectRatio['height'] === 'number' ? aspectRatio['height'] : undefined,
      }]
    })
  }

  // app.bsky.embed.recordWithMedia#view — has media sub-embed
  if (embed['$type'] === 'app.bsky.embed.recordWithMedia#view') {
    const media = asObj(embed['media'])
    if (media) return decodeImages(media)
  }

  return []
}

function decodeQuote(embed: Record<string, unknown>): NoteView | undefined {
  // app.bsky.embed.record#view
  if (embed['$type'] === 'app.bsky.embed.record#view') {
    const record = asObj(embed['record'])
    if (!record) return undefined
    return decodeEmbeddedRecord(record)
  }

  // app.bsky.embed.recordWithMedia#view — has record sub-embed
  if (embed['$type'] === 'app.bsky.embed.recordWithMedia#view') {
    const recordEmbed = asObj(embed['record'])
    if (recordEmbed) return decodeQuote(recordEmbed)
  }

  return undefined
}

function decodeEmbeddedRecord(record: Record<string, unknown>): NoteView | undefined {
  // app.bsky.embed.record#viewRecord
  const author = decodeAuthor(record['author'])
  if (!author) return undefined
  const value = asObj(record['value'])

  return {
    id: getString(record, 'uri') ?? '',
    user: author,
    text: value ? getString(value, 'text') ?? undefined : undefined,
    contentType: 'bluesky',
    facets: value ? decodeFacets(value) : undefined,
    cw: undefined,
    createdAt: getString(record, 'indexedAt') ?? '',
    files: [],
    reactions: {},
    reactionEmojis: {},
    myReaction: undefined,
    reactionAcceptance: undefined,
    renote: undefined,
    replyId: undefined,
    reply: undefined,
    uri: getString(record, 'uri') ?? undefined,
    poll: undefined,
  }
}

function decodeFacets(record: Record<string, unknown>): BlueskyFacet[] | undefined {
  const raw = record['facets']
  if (!Array.isArray(raw)) return undefined
  return raw.flatMap(f => {
    const obj = asObj(f)
    if (!obj) return []
    const index = asObj(obj['index'])
    if (!index) return []
    const byteStart = typeof index['byteStart'] === 'number' ? index['byteStart'] : undefined
    const byteEnd = typeof index['byteEnd'] === 'number' ? index['byteEnd'] : undefined
    if (byteStart === undefined || byteEnd === undefined) return []
    const features = Array.isArray(obj['features']) ? obj['features'] : []
    return [{ index: { byteStart, byteEnd }, features }]
  })
}

/** Decode a Bluesky FeedViewPost (from getTimeline/getAuthorFeed) into NoteView. */
export function decodeFeedViewPost(json: unknown): NoteView | undefined {
  const obj = asObj(json)
  if (!obj) return undefined

  // FeedViewPost has { post, reply?, reason? }
  const postObj = asObj(obj['post']) ?? obj
  return decodePostView(postObj as Record<string, unknown>, obj)
}

/** Decode a Bluesky PostView into NoteView. */
export function decodePostView(postObj: Record<string, unknown>, feedCtx?: Record<string, unknown>): NoteView | undefined {
  const author = decodeAuthor(postObj['author'])
  if (!author) return undefined

  const record = asObj(postObj['record'])
  const text = record ? getString(record, 'text') ?? undefined : undefined
  const facets = record ? decodeFacets(record) : undefined

  const embed = asObj(postObj['embed'])
  const files = embed ? decodeImages(embed) : []
  const quote = embed ? decodeQuote(embed) : undefined

  const likeCount = typeof postObj['likeCount'] === 'number' ? postObj['likeCount'] : 0
  const viewer = asObj(postObj['viewer'])
  const myLike = viewer ? getString(viewer, 'like') : undefined

  const reactions: Record<string, number> = likeCount > 0 ? { '❤️': likeCount } : {}

  const replyRef = record ? asObj(record['reply']) : undefined
  const replyParent = replyRef ? asObj(replyRef['parent']) : undefined
  const replyId = replyParent ? getString(replyParent, 'uri') : undefined

  // Check if this is a repost (reason type = reasonRepost)
  const reason = feedCtx ? asObj(feedCtx['reason']) : undefined
  const isRepost = reason && getString(reason, '$type') === 'app.bsky.feed.defs#reasonRepost'

  const cid = getString(postObj, 'cid') ?? ''
  const uri = getString(postObj, 'uri') ?? ''

  const note: NoteView = {
    id: uri,
    user: author,
    text,
    contentType: 'bluesky',
    facets,
    cw: undefined,
    createdAt: getString(postObj, 'indexedAt') ?? (record ? getString(record, 'createdAt') ?? '' : ''),
    files,
    reactions,
    reactionEmojis: {},
    myReaction: myLike ? '❤️' : undefined,
    reactionAcceptance: undefined,
    renote: quote,
    replyId,
    reply: undefined,
    uri,
    poll: undefined,
    // Store cid for like/repost operations
    _bskyCid: cid,
  }

  if (isRepost) {
    const reposter = decodeAuthor(reason!['by'])
    if (reposter) {
      return {
        id: `repost:${uri}`,
        user: reposter,
        text: undefined,
        contentType: 'bluesky',
        cw: undefined,
        createdAt: getString(reason!, 'indexedAt') ?? note.createdAt,
        files: [],
        reactions: {},
        reactionEmojis: {},
        myReaction: undefined,
        reactionAcceptance: undefined,
        renote: note,
        replyId: undefined,
        reply: undefined,
        uri: undefined,
        poll: undefined,
      }
    }
  }

  return note
}

export function decodeMany(items: unknown[]): NoteView[] {
  return items.flatMap(item => {
    const decoded = decodeFeedViewPost(item)
    return decoded ? [decoded] : []
  })
}

export function decodeManyFromJson(json: unknown): NoteView[] {
  if (!Array.isArray(json)) return []
  return decodeMany(json)
}
