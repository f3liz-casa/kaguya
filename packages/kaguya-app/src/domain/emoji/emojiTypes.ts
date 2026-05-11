// SPDX-License-Identifier: MPL-2.0

export type Emoji = {
  name: string
  url: string
  category: string | undefined
  aliases: string[]
}

export type EmojiMap = Record<string, Emoji>

export type LoadState =
  | 'NotLoaded'
  | 'Loading'
  | 'Loaded'
  | { type: 'LoadError'; message: string }
