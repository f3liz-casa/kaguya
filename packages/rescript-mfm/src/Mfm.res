// Main module for rescript-mfm
// Re-exports all public APIs with a clean interface

// ============================================================
// Core Types
// ============================================================

module Node = MfmNode

// Re-export node type
type node = MfmNode.Raw.node

// ============================================================
// API Module
// ============================================================

module API = MfmAPI

// Re-export main API functions at top level for convenience
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

// Re-export utility functions
let extractText = MfmAPI.extractAllText
let getNodeType = MfmAPI.getNodeType
let isNodeType = MfmAPI.isNodeType
let getAllOfType = MfmAPI.getAllOfType
let containsType = MfmAPI.containsType
