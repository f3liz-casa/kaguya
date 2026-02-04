// SPDX-License-Identifier: MPL-2.0
// NoteContent.res - Note content component (CW handling, text, MFM rendering)

@jsx.component
let make = (~note: NoteView.t, ~showContent: bool, ~onToggleCw: JsxEvent.Mouse.t => unit) => {
  <div className="note-content" role="region" ariaLabel="Note content">
    {switch // Content warning handling
    note.cw {
    | Some(cwText) =>
      <>
        <p className="content-warning" role="alert"> {Preact.string(cwText)} </p>
        <button
          className="cw-toggle secondary outline"
          onClick={onToggleCw}
          ariaLabel={showContent ? "Hide content" : "Show content"}
          ariaExpanded={showContent}
          type_="button"
        >
          {Preact.string(showContent ? "Hide" : "Show")}
        </button>
      </>
    | None => Preact.null
    }}

    {if showContent {
      switch note.text {
      | Some(t) =>
        <div className="note-text">
          <MfmRenderer text={t} />
        </div>
      | None => Preact.null
      }
    } else {
      Preact.null
    }}
  </div>
}
