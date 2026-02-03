// SPDX-License-Identifier: MPL-2.0
// PreactHooks.res - Preact hooks bindings

// ============================================================
// State Hooks
// ============================================================

@module("preact/hooks")
external useState: ('a => 'state) => ('state, ('state => 'state) => unit) = "useState"

@module("preact/hooks")
external useReducer: (
  ('state, 'action) => 'state,
  'state,
) => ('state, 'action => unit) = "useReducer"

// ============================================================
// Effect Hooks
// ============================================================

@module("preact/hooks")
external useEffect: (unit => option<unit => unit>) => unit = "useEffect"

@module("preact/hooks")
external useEffect0: (unit => option<unit => unit>, @as(json`[]`) _) => unit = "useEffect"

@module("preact/hooks")
external useEffect1: (unit => option<unit => unit>, array<'a>) => unit = "useEffect"

@module("preact/hooks")
external useEffect2: (unit => option<unit => unit>, ('a, 'b)) => unit = "useEffect"

@module("preact/hooks")
external useEffect3: (unit => option<unit => unit>, ('a, 'b, 'c)) => unit = "useEffect"

@module("preact/hooks")
external useLayoutEffect: (unit => option<unit => unit>) => unit = "useLayoutEffect"

@module("preact/hooks")
external useLayoutEffect0: (unit => option<unit => unit>, @as(json`[]`) _) => unit = "useLayoutEffect"

@module("preact/hooks")
external useLayoutEffect1: (unit => option<unit => unit>, array<'a>) => unit = "useLayoutEffect"

// ============================================================
// Ref Hooks
// ============================================================

type ref<'a> = {mutable current: 'a}

@module("preact/hooks")
external useRef: 'a => ref<'a> = "useRef"

// ============================================================
// Memoization Hooks
// ============================================================

@module("preact/hooks")
external useMemo: (unit => 'a, array<'dep>) => 'a = "useMemo"

@module("preact/hooks")
external useMemo0: (unit => 'a, @as(json`[]`) _) => 'a = "useMemo"

@module("preact/hooks")
external useMemo1: (unit => 'a, array<'dep>) => 'a = "useMemo"

@module("preact/hooks")
external useMemo2: (unit => 'a, ('a, 'b)) => 'a = "useMemo"

@module("preact/hooks")
external useCallback: ('a, array<'dep>) => 'a = "useCallback"

@module("preact/hooks")
external useCallback0: ('a, @as(json`[]`) _) => 'a = "useCallback"

@module("preact/hooks")
external useCallback1: ('a, array<'dep>) => 'a = "useCallback"

// ============================================================
// Context Hook
// ============================================================

@module("preact/hooks")
external useContext: Preact.component<{..}> => 'a = "useContext"

// ============================================================
// Other Hooks
// ============================================================

@module("preact/hooks")
external useErrorBoundary: unit => (option<exn>, unit => unit) = "useErrorBoundary"

@module("preact/hooks")
external useId: unit => string = "useId"
