// SPDX-License-Identifier: MPL-2.0

@jsx.component
let make = (~url: string, ~name: string, ~onClose: unit => unit) => {
  PreactHooks.useEffect1(() => {
    let handleEscape = (e: JsxEvent.Keyboard.t) => {
      if JsxEvent.Keyboard.key(e) == "Escape" {
        onClose()
      }
    }
    Document.addEventListener("keydown", handleEscape)
    Some(() => Document.removeEventListener("keydown", handleEscape))
  }, [onClose])

  PreactHooks.useEffect0(() => {
    Document.setBodyOverflow("hidden")
    Some(() => Document.setBodyOverflow(""))
  })

  <div
    className="lightbox-overlay"
    onClick={_ => onClose()}
    role="dialog"
    ariaModal={true}
    ariaLabel="画像ビューア"
  >
    <div className="lightbox-content" onClick={e => e->JsxEvent.Mouse.stopPropagation}>
      <button
        className="lightbox-close"
        onClick={_ => onClose()}
        ariaLabel="画像ビューアを閉じる"
        type_="button"
      >
        {Preact.string("×")}
      </button>
      <img className="lightbox-image" src={url} alt={name} onClick={_ => onClose()} role="img" />
    </div>
  </div>
}
