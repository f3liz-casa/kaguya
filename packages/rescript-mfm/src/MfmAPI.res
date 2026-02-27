// MfmAPI - ReScript wrapper for mfm-rs WASM parser

// ============================================================
// Parse Options
// ============================================================

type parseOptions = {nestLimit?: int}

// ============================================================
// External bindings to mfm-rs (WASM)
// ============================================================

@module("mfm-rs")
external parseRawWithoutOptions: string => array<MfmNode.Raw.node> = "parse"

@module("mfm-rs")
external parseRawWithLimit: (string, int) => array<MfmNode.Raw.node> = "parseWithLimit"

@module("mfm-rs")
external parseSimpleRaw: string => array<MfmNode.Raw.node> = "parseSimple"

// ============================================================
// High-level API
// ============================================================

let parse = (~nestLimit=?, input: string): array<MfmNode.Raw.node> => {
  switch nestLimit {
  | Some(limit) => parseRawWithLimit(input, limit)
  | None => parseRawWithoutOptions(input)
  }
}

let parseSimple = (input: string): array<MfmNode.Raw.node> => {
  parseSimpleRaw(input)
}

// ============================================================
// Pure ReScript utility functions
// ============================================================

let rec toStringNode = (node: MfmNode.Raw.node): string => {
  let childrenStr = (n: MfmNode.Raw.node) =>
    switch n.children {
    | Some(children) => children->Array.map(toStringNode)->Array.join("")
    | None => ""
    }

  let getProp = (key: string) =>
    node.props->Option.flatMap(p => Dict.get(p, key))->Option.flatMap(JSON.Decode.string)->Option.getOr("")

  let getNullProp = (key: string) =>
    node.props
    ->Option.flatMap(p => Dict.get(p, key))
    ->Option.flatMap(v =>
      switch v {
      | JSON.Null => None
      | _ => JSON.Decode.string(v)
      }
    )

  switch node.type_ {
  | "text" => getProp("text")
  | "bold" => "**" ++ childrenStr(node) ++ "**"
  | "italic" => "<i>" ++ childrenStr(node) ++ "</i>"
  | "strike" => "~~" ++ childrenStr(node) ++ "~~"
  | "small" => "<small>" ++ childrenStr(node) ++ "</small>"
  | "inlineCode" => "`" ++ getProp("code") ++ "`"
  | "blockCode" => {
      let lang = getNullProp("lang")->Option.getOr("")
      "```" ++ lang ++ "\n" ++ getProp("code") ++ "\n```"
    }
  | "quote" =>
    childrenStr(node)
    ->String.split("\n")
    ->Array.map(l => "> " ++ l)
    ->Array.join("\n")
  | "center" => "<center>" ++ childrenStr(node) ++ "</center>"
  | "url" => getProp("url")
  | "link" => "[" ++ childrenStr(node) ++ "](" ++ getProp("url") ++ ")"
  | "mention" => {
      let username = getProp("username")
      switch getNullProp("host") {
      | Some(h) => "@" ++ username ++ "@" ++ h
      | None => "@" ++ username
      }
    }
  | "hashtag" => "#" ++ getProp("hashtag")
  | "emojiCode" => ":" ++ getProp("name") ++ ":"
  | "unicodeEmoji" => getProp("emoji")
  | "mathInline" => "\\(" ++ getProp("formula") ++ "\\)"
  | "mathBlock" => "\\[\n" ++ getProp("formula") ++ "\n\\]"
  | "search" => getProp("query") ++ " 検索"
  | "fn" => "$[" ++ getProp("name") ++ " " ++ childrenStr(node) ++ "]"
  | "plain" => "<plain>" ++ childrenStr(node) ++ "</plain>"
  | _ => ""
  }
}

let toString = (nodes: array<MfmNode.Raw.node>): string => {
  nodes->Array.map(toStringNode)->Array.join("")
}

let rec inspectSingleNode = (node: MfmNode.Raw.node, action: MfmNode.Raw.node => unit): unit => {
  action(node)
  switch node.children {
  | Some(children) => children->Array.forEach(child => inspectSingleNode(child, action))
  | None => ()
  }
}

let inspectNodes = (nodes: array<MfmNode.Raw.node>, action: MfmNode.Raw.node => unit): unit => {
  nodes->Array.forEach(node => inspectSingleNode(node, action))
}

let inspectNode = (node: MfmNode.Raw.node, action: MfmNode.Raw.node => unit): unit => {
  inspectSingleNode(node, action)
}

let rec extractFromNode = (
  node: MfmNode.Raw.node,
  predicate: MfmNode.Raw.node => bool,
  acc: array<MfmNode.Raw.node>,
): unit => {
  if predicate(node) {
    Array.push(acc, node)
  }
  switch node.children {
  | Some(children) => children->Array.forEach(child => extractFromNode(child, predicate, acc))
  | None => ()
  }
}

let extractNodes = (
  nodes: array<MfmNode.Raw.node>,
  predicate: MfmNode.Raw.node => bool,
): array<MfmNode.Raw.node> => {
  let acc = []
  nodes->Array.forEach(node => extractFromNode(node, predicate, acc))
  acc
}

// ============================================================
// Utility functions for working with nodes
// ============================================================

let rec extractText = (node: MfmNode.Raw.node): string => {
  let nodeType = node.type_

  if nodeType === "text" {
    switch node.props {
    | Some(props) =>
      switch Dict.get(props, "text") {
      | Some(text) => JSON.Decode.string(text)->Option.getOr("")
      | None => ""
      }
    | None => ""
    }
  } else {
    switch node.children {
    | Some(children) => children->Array.map(extractText)->Array.join("")
    | None => ""
    }
  }
}

let extractAllText = (nodes: array<MfmNode.Raw.node>): string => {
  nodes->Array.map(extractText)->Array.join("")
}

let getNodeType = (node: MfmNode.Raw.node): string => {
  node.type_
}

let isNodeType = (node: MfmNode.Raw.node, nodeType: string): bool => {
  node.type_ === nodeType
}

let getAllOfType = (nodes: array<MfmNode.Raw.node>, nodeType: string): array<MfmNode.Raw.node> => {
  extractNodes(nodes, node => isNodeType(node, nodeType))
}

let containsType = (nodes: array<MfmNode.Raw.node>, nodeType: string): bool => {
  getAllOfType(nodes, nodeType)->Array.length > 0
}
