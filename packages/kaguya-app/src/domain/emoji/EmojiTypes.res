// SPDX-License-Identifier: MPL-2.0

type emoji = {
  name: string,
  url: string,
  category: option<string>,
  aliases: array<string>,
}

type emojiMap = Dict.t<emoji>

type loadState =
  | NotLoaded
  | Loading
  | Loaded
  | LoadError(string)

type cacheMetadata = {
  timestamp: float,
  instanceOrigin: string,
}
