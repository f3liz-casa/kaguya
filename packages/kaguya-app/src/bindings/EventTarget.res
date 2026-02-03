// SPDX-License-Identifier: MPL-2.0
// EventTarget.res - Event target bindings for DOM events

// ============================================================
// Common Properties - works with any JS object with these properties
// ============================================================

@get
external getValue: 'a => string = "value"

@get
external getScrollTop: 'a => int = "scrollTop"

@get
external getScrollLeft: 'a => int = "scrollLeft"

@get
external getChecked: 'a => bool = "checked"

@get
external getFiles: 'a => array<'file> = "files"

@get
external getTagName: 'a => string = "tagName"

@get
external getId: 'a => string = "id"

@get
external getClassName: 'a => string = "className"
