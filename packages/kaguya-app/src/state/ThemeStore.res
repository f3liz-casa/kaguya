// SPDX-License-Identifier: MPL-2.0
// ThemeStore.res - Light/dark mode preference management

// ============================================================
// Types
// ============================================================

type theme = Light | Dark | System

// ============================================================
// FFI
// ============================================================

@val @scope("localStorage")
external getItem: string => Nullable.t<string> = "getItem"

@val @scope("localStorage")
external setItem: (string, string) => unit = "setItem"

@val @scope("localStorage")
external removeItem: string => unit = "removeItem"

@val @scope(("document", "documentElement"))
external setAttribute: (string, string) => unit = "setAttribute"

@val @scope(("document", "documentElement"))
external removeAttribute: string => unit = "removeAttribute"

@val
external matchMediaQuery: string => {"matches": bool} = "matchMedia"

// ============================================================
// State
// ============================================================

let storageKey = "kaguya:theme"

let currentTheme: PreactSignals.signal<theme> = PreactSignals.make(System)

// ============================================================
// Helpers
// ============================================================

let applyTheme = (theme: theme) => {
  switch theme {
  | Light => setAttribute("data-theme", "light")
  | Dark => setAttribute("data-theme", "dark")
  | System => removeAttribute("data-theme")
  }
}

let init = () => {
  let stored = getItem(storageKey)->Nullable.toOption
  let theme = switch stored {
  | Some("light") => Light
  | Some("dark") => Dark
  | _ => System
  }
  PreactSignals.setValue(currentTheme, theme)
  applyTheme(theme)
}

let toggle = () => {
  let current = PreactSignals.value(currentTheme)
  // Cycle: System → Dark → Light → System
  // Simplified: just toggle between Dark and Light (respect system if not set)
  let sysDark = (matchMediaQuery("(prefers-color-scheme: dark)"))["matches"]
  let next = switch current {
  | System => if sysDark { Light } else { Dark }
  | Light => Dark
  | Dark => Light
  }
  PreactSignals.setValue(currentTheme, next)
  applyTheme(next)
  switch next {
  | Light => setItem(storageKey, "light")
  | Dark => setItem(storageKey, "dark")
  | System => removeItem(storageKey)
  }
}

let isDark = () => {
  switch PreactSignals.value(currentTheme) {
  | Dark => true
  | Light => false
  | System => (matchMediaQuery("(prefers-color-scheme: dark)"))["matches"]
  }
}
