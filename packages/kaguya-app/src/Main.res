// SPDX-License-Identifier: MPL-2.0
// Main.res - Application entry point

S.enableJson()
S.enableJsonString()

// UnoCSS virtual stylesheet (utility classes)
%%raw(`import 'virtual:uno.css'`)
// Normalize CSS reset
%%raw(`import '@unocss/reset/normalize.css'`)
// Bundle Tabler icons offline (avoids CDN fetch)
%%raw(`import '@kaguya-src/icons.ts'`)

// DOM bindings
@val @scope("document")
external getElementById: string => Nullable.t<Dom.element> = "getElementById"

// Render the app to the DOM
switch getElementById("root")->Nullable.toOption {
| Some(root) => PreactRender.render(<KaguyaApp />, root)
| None => Console.error("Could not find root element")
}
