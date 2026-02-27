// SPDX-License-Identifier: MPL-2.0

let isInteractiveClick = (e: JsxEvent.Mouse.t): bool => {
  let target: Dom.element = e->JsxEvent.Mouse.target->Obj.magic
  let tagName: string = (target->Obj.magic)["tagName"]
  let interactive = tagName == "A" || tagName == "BUTTON" || tagName == "IMG" || tagName == "INPUT"
  let closest: Nullable.t<Dom.element> = (target->Obj.magic)["closest"](
    "a, button, .reaction-button, .lightbox-overlay, .sensitive-overlay, .image-attachment",
  )
  interactive || !Nullable.isNullable(closest)
}

@jsx.component
let make = (~note: NoteView.t, ~noteHost: option<string>=?) => {
  let _ = PerfMonitor.useRenderMetrics(~component="Note")
  let (_, navigate) = Wouter.useLocation()
  let localHost = PreactSignals.value(AppState.instanceName)
  let effectiveHost = noteHost->Option.getOr(localHost)

  let (showContent, setShowContent) = PreactHooks.useState(() =>
    !NoteView.hasContentWarning(note)
  )
  let handleToggleCw = (_: JsxEvent.Mouse.t) => setShowContent(prev => !prev)

  let isPureRenote = NoteView.isPureRenote(note)

  let handleNoteClick = (e: JsxEvent.Mouse.t) => {
    if !isInteractiveClick(e) {
      navigate("/notes/" ++ note.id ++ "/" ++ effectiveHost)
    }
  }

  <article
    className="note note-clickable"
    role="article"
    ariaLabel={note.user.name ++ " のノート"}
    onClick={handleNoteClick}
  >
    {switch note.reply {
    | Some(parent) =>
      <div className="note-reply-parent">
        <div className="note-reply-connector" />
        <div className="note-reply-parent-content">
          <NoteHeader user={parent.user} createdAt={parent.createdAt} noteId={parent.id} contextHost={effectiveHost} />
          {switch parent.text {
          | Some(t) =>
            <div className="note-text">
              <MfmRenderer text={t} contextHost={effectiveHost} />
            </div>
          | None => Preact.null
          }}
        </div>
      </div>
    | None => Preact.null
    }}

    {if isPureRenote {
      <div className="renote-indicator" role="status" ariaLabel={note.user.name ++ " がリノート"}>
        <small> <MfmRenderer text={note.user.name} parseSimple=true /> {Preact.string(" がリノート")} </small>
      </div>
    } else {
      Preact.null
    }}

    <NoteHeader user={note.user} createdAt={note.createdAt} noteId={note.id} contextHost={effectiveHost} />
    <NoteContent note showContent onToggleCw={handleToggleCw} contextHost={effectiveHost} />

    {switch note.renote {
    | Some(renoteData) if isPureRenote =>
      <div className="renoted-note renoted-note-clickable" onClick={e => {
        if !isInteractiveClick(e) {
          e->JsxEvent.Mouse.stopPropagation
          navigate("/notes/" ++ renoteData.id ++ "/" ++ effectiveHost)
        }
      }}>
        <NoteHeader user={renoteData.user} createdAt={renoteData.createdAt} noteId={renoteData.id} contextHost={effectiveHost} />
        {switch renoteData.text {
        | Some(t) =>
          <div className="note-text">
            <MfmRenderer text={t} contextHost={effectiveHost} />
          </div>
        | None => Preact.null
        }}
        <ImageGallery files={renoteData.files} />
        <ReactionBar
          noteId={renoteData.id}
          reactions={renoteData.reactions}
          reactionEmojis={renoteData.reactionEmojis}
          myReaction={renoteData.myReaction}
          reactionAcceptance={renoteData.reactionAcceptance}
        />
      </div>
    | _ => Preact.null
    }}

    {if !isPureRenote {
      <>
        <ImageGallery files={note.files} />
        <ReactionBar
          noteId={note.id}
          reactions={note.reactions}
          reactionEmojis={note.reactionEmojis}
          myReaction={note.myReaction}
          reactionAcceptance={note.reactionAcceptance}
        />
        <NoteActions
          noteId={note.id}
          noteHost={effectiveHost}
          reactionAcceptance=?{note.reactionAcceptance}
        />
      </>
    } else {
      <ImageGallery files={note.files} />
    }}
  </article>
}
