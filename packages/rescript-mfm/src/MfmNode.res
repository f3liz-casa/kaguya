// MfmNode type definitions - ReScript bindings for mfm-js
// This mirrors the TypeScript types from mfm.js/src/node.ts

// ============================================================
// External JS types (for interop with mfm-js)
// ============================================================

// These types represent the raw JS objects from mfm-js
// We use a simple representation that matches the runtime structure
module Raw = {
  type rec node = {
    @as("type") type_: string,
    props?: Dict.t<JSON.t>,
    children?: array<node>,
  }
}
