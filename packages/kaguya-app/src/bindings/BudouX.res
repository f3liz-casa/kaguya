// SPDX-License-Identifier: MPL-2.0

type parser

@module("budoux")
external loadDefaultJapaneseParser: unit => parser = "loadDefaultJapaneseParser"

@send
external parse: (parser, string) => array<string> = "parse"

// Singleton parser instance
let japaneseParser = loadDefaultJapaneseParser()

// Returns true if the text likely contains Japanese characters
let hasJapanese = (text: string): bool => {
  let re = %re("/[\u3000-\u9FFF\uF900-\uFAFF\uFF00-\uFFEF]/")
  re->Js.Re.test_(text)
}

// Returns true if the text contains Korean (Hangul) characters
let hasKorean = (text: string): bool => {
  let re = %re("/[\uAC00-\uD7AF\u1100-\u11FF\u3130-\u318F\uA960-\uA97F\uD7B0-\uD7FF]/")
  re->Js.Re.test_(text)
}

let parseJapanese = (text: string): array<string> => {
  japaneseParser->parse(text)
}
