// SPDX-License-Identifier: MPL-2.0

@jsx.component
let make = (~note: NoteView.t, ~showContent: bool, ~onToggleCw: JsxEvent.Mouse.t => unit, ~contextHost: option<string>=?) => {
  <div className="note-content" role="region" ariaLabel="Note content">
    {switch // Content warning handling
    note.cw {
    | Some(cwText) =>
      <>
        <p className="content-warning" role="alert"> {Preact.string(cwText)} </p>
        <button
          className="cw-toggle secondary outline"
          onClick={onToggleCw}
          ariaLabel={showContent ? "たたむ" : "みる"}
          ariaExpanded={showContent}
          type_="button"
        >
          {Preact.string(showContent ? "たたむ" : "みる")}
        </button>
      </>
    | None => Preact.null
    }}

    {if showContent {
      switch note.text {
      | Some(t) =>
        <div className="note-text">
          <MfmRenderer text={t} ?contextHost />
        </div>
      | None => Preact.null
      }
    } else {
      Preact.null
    }}
  </div>
}
