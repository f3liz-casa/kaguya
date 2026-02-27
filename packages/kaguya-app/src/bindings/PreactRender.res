// SPDX-License-Identifier: MPL-2.0

@module("preact")
external render: (Preact.element, Dom.element) => unit = "render"

@module("preact")
external hydrate: (Preact.element, Dom.element) => unit = "hydrate"
