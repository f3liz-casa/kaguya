// MfmAPI - ReScript bindings for mfm-js API functions
// This mirrors the TypeScript API from mfm.js/src/api.ts

// ============================================================
// Parse Options
// ============================================================

type parseOptions = {nestLimit?: int}

// ============================================================
// External bindings to mfm-js
// ============================================================

@module("mfm-js")
external parseRaw: (string, parseOptions) => array<MfmNode.Raw.node> = "parse"

@module("mfm-js")
external parseRawWithoutOptions: string => array<MfmNode.Raw.node> = "parse"

@module("mfm-js")
external parseSimpleRaw: string => array<MfmNode.Raw.node> = "parseSimple"

@module("mfm-js")
external toStringArray: array<MfmNode.Raw.node> => string = "toString"

@module("mfm-js")
external toStringSingle: MfmNode.Raw.node => string = "toString"

@module("mfm-js")
external inspect: (array<MfmNode.Raw.node>, MfmNode.Raw.node => unit) => unit = "inspect"

@module("mfm-js")
external inspectSingle: (MfmNode.Raw.node, MfmNode.Raw.node => unit) => unit = "inspect"

@module("mfm-js")
external extract: (
  array<MfmNode.Raw.node>,
  MfmNode.Raw.node => bool,
) => array<MfmNode.Raw.node> = "extract"

// ============================================================
// High-level API (with default options)
// ============================================================

/**
 * Parses MFM text into an array of MFM nodes.
 * 
 * @param input - The MFM text to parse
 * @param options - Optional parse options (nestLimit)
 * @returns Array of parsed MFM nodes
 * 
 * @example
 * let nodes = MfmAPI.parse("Hello **world**!")
 */
let parse = (~nestLimit=?, input: string): array<MfmNode.Raw.node> => {
  switch nestLimit {
  | Some(limit) => parseRaw(input, {nestLimit: limit})
  | None => parseRawWithoutOptions(input)
  }
}

/**
 * Parses simple MFM text (only emoji and text).
 * This is useful for parsing user names and other simple text.
 * 
 * @param input - The simple MFM text to parse
 * @returns Array of simple MFM nodes (emoji and text only)
 * 
 * @example
 * let nodes = MfmAPI.parseSimple("I like the hot soup :soup:")
 */
let parseSimple = (input: string): array<MfmNode.Raw.node> => {
  parseSimpleRaw(input)
}

/**
 * Converts MFM nodes back to MFM text.
 * 
 * @param nodes - Array of MFM nodes or a single node
 * @returns MFM text representation
 * 
 * @example
 * let text = MfmAPI.toString(nodes)
 */
let toString = (nodes: array<MfmNode.Raw.node>): string => {
  toStringArray(nodes)
}

let toStringNode = (node: MfmNode.Raw.node): string => {
  toStringSingle(node)
}

/**
 * Inspects the MFM tree and executes a callback for each node.
 * 
 * @param nodes - Array of MFM nodes or a single node
 * @param action - Callback function to execute for each node
 * 
 * @example
 * MfmAPI.inspect(nodes, node => {
 *   Console.log(node.type_)
 * })
 */
let inspectNodes = (nodes: array<MfmNode.Raw.node>, action: MfmNode.Raw.node => unit): unit => {
  inspect(nodes, action)
}

let inspectNode = (node: MfmNode.Raw.node, action: MfmNode.Raw.node => unit): unit => {
  inspectSingle(node, action)
}

/**
 * Extracts nodes from the MFM tree that match a predicate.
 * 
 * @param nodes - Array of MFM nodes
 * @param predicate - Function that returns true for nodes to extract
 * @returns Array of matching nodes
 * 
 * @example
 * let mentions = MfmAPI.extract(nodes, node => node.type_ === "mention")
 */
let extractNodes = (
  nodes: array<MfmNode.Raw.node>,
  predicate: MfmNode.Raw.node => bool,
): array<MfmNode.Raw.node> => {
  extract(nodes, predicate)
}

// ============================================================
// Utility functions for working with nodes
// ============================================================

/**
 * Extracts all text content from MFM nodes.
 */
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

/**
 * Gets the type of a node as a string.
 */
let getNodeType = (node: MfmNode.Raw.node): string => {
  node.type_
}

/**
 * Checks if a node is of a specific type.
 */
let isNodeType = (node: MfmNode.Raw.node, nodeType: string): bool => {
  node.type_ === nodeType
}

/**
 * Gets all nodes of a specific type from the tree.
 */
let getAllOfType = (nodes: array<MfmNode.Raw.node>, nodeType: string): array<MfmNode.Raw.node> => {
  extractNodes(nodes, node => isNodeType(node, nodeType))
}

/**
 * Checks if the MFM tree contains any nodes of a specific type.
 */
let containsType = (nodes: array<MfmNode.Raw.node>, nodeType: string): bool => {
  getAllOfType(nodes, nodeType)->Array.length > 0
}
