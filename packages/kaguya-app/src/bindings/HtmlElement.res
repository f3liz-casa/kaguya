// SPDX-License-Identifier: MPL-2.0
// HtmlElement.res - HTML Element manipulation bindings

// ============================================================
// Element Style Manipulation - works with any JS object
// ============================================================

@get @scope("style")
external getBackground: 'a => string = "background"

@set @scope("style")
external setBackground: ('a, string) => unit = "background"

@get @scope("style")
external getColor: 'a => string = "color"

@set @scope("style")
external setColor: ('a, string) => unit = "color"

@get @scope("style")
external getDisplay: 'a => string = "display"

@set @scope("style")
external setDisplay: ('a, string) => unit = "display"

@get @scope("style")
external getOverflow: 'a => string = "overflow"

@set @scope("style")
external setOverflow: ('a, string) => unit = "overflow"

@get @scope("style")
external getCursor: 'a => string = "cursor"

@set @scope("style")
external setCursor: ('a, string) => unit = "cursor"

@get @scope("style")
external getOpacity: 'a => string = "opacity"

@set @scope("style")
external setOpacity: ('a, string) => unit = "opacity"

// Helper to get computed color (same as getColor)
let getComputedColor = getColor
