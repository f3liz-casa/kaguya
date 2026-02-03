// SPDX-License-Identifier: MPL-2.0
// Wouter.res - wouter-preact router bindings

// ============================================================
// Types
// ============================================================

type params = Dict.t<string>

type navigationOptions = {
  replace: bool,
}

// ============================================================
// Hooks
// ============================================================

// Get current location and navigate function with options support
@module("wouter-preact")
external useLocationWithOptions: unit => (string, (string, navigationOptions) => unit) = "useLocation"

// Get current location (basic version)
@module("wouter-preact")
external useLocation: unit => (string, string => unit) = "useLocation"

// Get search string (query params)
@module("wouter-preact")
external useSearch: unit => string = "useSearch"

// Match a route pattern, returns (matched, params)
@module("wouter-preact")
external useRoute: string => (bool, Nullable.t<params>) = "useRoute"

// Get route params for current route
@module("wouter-preact")
external useParams: unit => params = "useParams"

// ============================================================
// Components
// ============================================================

module Route = {
  @module("wouter-preact") @react.component
  external make: (~path: string, ~children: Preact.element) => Preact.element = "Route"
}

module Link = {
  @module("wouter-preact") @react.component
  external make: (
    ~href: string,
    ~children: Preact.element,
    ~className: string=?,
    ~onClick: JsxEvent.Mouse.t => unit=?,
  ) => Preact.element = "Link"
}

module Switch = {
  @module("wouter-preact") @react.component
  external make: (~children: Preact.element) => Preact.element = "Switch"
}

module Redirect = {
  @module("wouter-preact") @react.component
  external make: (~to: string) => Preact.element = "Redirect"
}

// ============================================================
// Navigation Helpers
// ============================================================

// Programmatic navigation helper (must be called inside a component)
let useNavigate = (): (string => unit) => {
  let (_, setLocation) = useLocation()
  setLocation
}

// Programmatic navigation helper with options (for replace, etc.)
let useNavigateWithOptions = (): ((string, navigationOptions) => unit) => {
  let (_, setLocation) = useLocationWithOptions()
  setLocation
}
