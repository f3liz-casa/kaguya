// SPDX-License-Identifier: MPL-2.0

// Document Body Bindings

@val @scope("document") @scope("body") @scope("style")
external setOverflow: string => unit = "overflow"

let setBodyOverflow = (value: string): unit => {
  setOverflow(value)
}

// Document Event Listener Bindings

@val @scope("document")
external addEventListenerKeydown: (@as("keydown") _, JsxEvent.Keyboard.t => unit) => unit =
  "addEventListener"

@val @scope("document")
external removeEventListenerKeydown: (@as("keydown") _, JsxEvent.Keyboard.t => unit) => unit =
  "removeEventListener"

// Generic event listener for flexibility
@val @scope("document")
external addEventListener: (string, 'event => unit) => unit = "addEventListener"

@val @scope("document")
external removeEventListener: (string, 'event => unit) => unit = "removeEventListener"

@val @scope("document")
external visibilityState: string = "visibilityState"
