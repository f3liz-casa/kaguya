// SPDX-License-Identifier: MPL-2.0
// Preact.res - Generic JSX transform module for Preact

// ============================================================
// Core JSX Types
// ============================================================

type element = Jsx.element
type component<'props> = Jsx.component<'props>
type componentLike<'props, 'return> = Jsx.componentLike<'props, 'return>

// ============================================================
// JSX Runtime Functions
// ============================================================

@module("preact/jsx-runtime")
external jsx: (component<'props>, 'props) => element = "jsx"

@module("preact/jsx-runtime")
external jsxKeyed: (component<'props>, 'props, ~key: string=?, @ignore unit) => element = "jsx"

@module("preact/jsx-runtime")
external jsxs: (component<'props>, 'props) => element = "jsxs"

@module("preact/jsx-runtime")
external jsxsKeyed: (component<'props>, 'props, ~key: string=?, @ignore unit) => element = "jsxs"

// ============================================================
// Element Conversion Helpers
// ============================================================

external array: array<element> => element = "%identity"
@val external null: element = "null"
external float: float => element = "%identity"
external int: int => element = "%identity"
external string: string => element = "%identity"
external promise: promise<element> => element = "%identity"

// ============================================================
// Fragment Support
// ============================================================

type fragmentProps = {children?: element}

@module("preact/jsx-runtime")
external jsxFragment: component<fragmentProps> = "Fragment"

// ============================================================
// Elements Module (for lowercase JSX elements like <div>)
// ============================================================

module Elements = {
  type props = JsxDOM.domProps

  @module("preact/jsx-runtime")
  external jsx: (string, props) => Jsx.element = "jsx"

  @module("preact/jsx-runtime")
  external div: (string, props) => Jsx.element = "jsx"

  @module("preact/jsx-runtime")
  external jsxKeyed: (string, props, ~key: string=?, @ignore unit) => Jsx.element = "jsx"

  @module("preact/jsx-runtime")
  external jsxs: (string, props) => Jsx.element = "jsxs"

  @module("preact/jsx-runtime")
  external jsxsKeyed: (string, props, ~key: string=?, @ignore unit) => Jsx.element = "jsxs"

  external someElement: element => option<element> = "%identity"
}
