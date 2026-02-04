// SPDX-License-Identifier: MPL-2.0
// Main.res - Application entry point

// DOM bindings
@val @scope("document")
external getElementById: string => Nullable.t<Dom.element> = "getElementById"

// Render the app to the DOM
switch getElementById("root")->Nullable.toOption {
| Some(root) => PreactRender.render(<KaguyaApp />, root)
| None => Console.error("Could not find root element")
}
