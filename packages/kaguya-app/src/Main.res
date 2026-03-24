// SPDX-License-Identifier: MPL-2.0

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

// Register SW and show a toast when a new version is waiting
%%raw(`
import { Serwist } from "@serwist/window";
import * as ToastState from "./ui/ToastState.mjs";
if ("serviceWorker" in navigator) {
  const serwist = new Serwist("/sw.js");
  serwist.addEventListener("waiting", () => {
    ToastState.showInfoWithAction(
      "新しいバージョンが利用可能です",
      { label: "今すぐ更新", onClick: () => serwist.messageSkipWaiting() }
    );
  });
  serwist.addEventListener("controlling", () => window.location.reload());
  serwist.register();
}
`)

switch getElementById("root")->Nullable.toOption {
| Some(root) => PreactRender.render(<KaguyaApp />, root)
| None => Console.error("Could not find root element")
}
