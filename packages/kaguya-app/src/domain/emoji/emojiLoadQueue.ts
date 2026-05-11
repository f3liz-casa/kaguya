// SPDX-License-Identifier: MPL-2.0

/**
 * @deprecated Use ../../infra/fetchQueue directly.
 * This file is a thin compatibility shim kept for any remaining callers.
 */

export type EmojiPriority = 1 | 2 | 3

export {
  shouldSkipBackgroundLoading as shouldSkipCacheWarming,
  enqueue,
  enqueueMany,
  boostPriority,
  isLoaded,
  observeImage as observeEmojiImage,
  unobserveImage as unobserveEmojiImage,
} from '../../infra/fetchQueue'
