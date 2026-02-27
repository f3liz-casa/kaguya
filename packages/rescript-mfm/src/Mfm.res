// Main module for rescript-mfm (powered by mfm-rs WASM)

// ============================================================
// Core Types
// ============================================================

module Node = MfmNode

type node = MfmNode.Raw.node

// ============================================================
// API Module
// ============================================================

module API = MfmAPI

// Re-export main API functions
let parse = MfmAPI.parse
let parseSimple = MfmAPI.parseSimple
let toString = MfmAPI.toString
let toStringNode = MfmAPI.toStringNode
let inspect = MfmAPI.inspectNodes
let inspectNode = MfmAPI.inspectNode
let extract = MfmAPI.extractNodes

// ============================================================
// Utility Functions
// ============================================================

let extractText = MfmAPI.extractAllText
let getNodeType = MfmAPI.getNodeType
let isNodeType = MfmAPI.isNodeType
let getAllOfType = MfmAPI.getAllOfType
let containsType = MfmAPI.containsType
