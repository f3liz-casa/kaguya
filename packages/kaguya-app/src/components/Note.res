// SPDX-License-Identifier: MPL-2.0
// Note.res - Note display component (refactored with typed data)

// ============================================================
// Image Components (Local Modules)
// ============================================================

// Lightbox modal component
module ImageLightbox = {
  @jsx.component
  let make = (~url: string, ~name: string, ~onClose: unit => unit) => {
    // Handle escape key to close
    PreactHooks.useEffect1(() => {
      let handleEscape = (e: JsxEvent.Keyboard.t) => {
        if JsxEvent.Keyboard.key(e) == "Escape" {
          onClose()
        }
      }

      Document.addEventListener("keydown", handleEscape)
      Some(() => Document.removeEventListener("keydown", handleEscape))
    }, [onClose])

    // Prevent body scroll when lightbox is open
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
}

// Component for rendering a single image
module ImageAttachment = {
  @jsx.component
  let make = (~file: FileView.t) => {
    let (showSensitive, setShowSensitive) = PreactHooks.useState(() => !file.isSensitive)
    let (showLightbox, setShowLightbox) = PreactHooks.useState(() => false)
    let (imageLoaded, setImageLoaded) = PreactHooks.useState(() => false)

    let thumbnailUrl = file.thumbnailUrl->Option.getOr(file.url)

    // Only render if it's an image
    if FileView.isImage(file) && file.url != "" {
      let cursorStyle = Style.make(~cursor=showSensitive ? "zoom-in" : "default", ())

      <>
        <div
          className="image-attachment"
          role="button"
          tabIndex={showSensitive ? 0 : -1}
          ariaLabel={file.isSensitive && !showSensitive
            ? "閲覧注意の画像、タップで表示"
            : "画像を拡大: " ++ file.name}
        >
          {if file.isSensitive && !showSensitive {
            <div
              className="sensitive-overlay"
              onClick={_ => setShowSensitive(_ => true)}
              role="button"
              tabIndex={0}
              ariaLabel="閲覧注意のコンテンツを表示"
            >
              <div className="sensitive-warning" ariaHidden={true}>
                <span className="sensitive-icon"> {Preact.string("⚠️")} </span>
                <span className="sensitive-text"> {Preact.string("閲覧注意")} </span>
                <small className="sensitive-hint"> {Preact.string("タップで表示")} </small>
              </div>
            </div>
          } else {
            Preact.null
          }}
          // Thumbnail as blur placeholder
          {if !imageLoaded && thumbnailUrl != file.url {
            <img
              className={file.isSensitive && !showSensitive
                ? "image-sensitive-hidden"
                : "image-placeholder"}
              src={thumbnailUrl}
              width=?{file.width->Option.map(w => Int.toString(w))}
              height=?{file.height->Option.map(h => Int.toString(h))}
              alt=""
              ariaHidden={true}
              role="presentation"
            />
          } else {
            Preact.null
          }}
          // Full resolution image
          <img
            className={if file.isSensitive && !showSensitive {
              "image-sensitive-hidden"
            } else if imageLoaded {
              "image-content image-loaded"
            } else {
              "image-content image-loading"
            }}
            src={file.url}
            width=?{file.width->Option.map(w => Int.toString(w))}
            height=?{file.height->Option.map(h => Int.toString(h))}
            alt={file.name}
            loading=#lazy
            onLoad={_ => setImageLoaded(_ => true)}
            onClick={e => {
              e->JsxEvent.Mouse.stopPropagation
              if showSensitive {
                setShowLightbox(_ => true)
              }
            }}
            style={cursorStyle}
            role="img"
            ariaHidden={file.isSensitive && !showSensitive}
          />
        </div>
        {if showLightbox {
          <ImageLightbox
            url={file.url} name={file.name} onClose={() => setShowLightbox(_ => false)}
          />
        } else {
          Preact.null
        }}
      </>
    } else {
      Preact.null
    }
  }
}

// Component for rendering image gallery
module ImageGallery = {
  @jsx.component
  let make = (~files: array<FileView.t>) => {
    // Filter only image files
    let imageFiles = files->Array.filter(FileView.isImage)

    if imageFiles->Array.length > 0 {
      let gridClass = switch imageFiles->Array.length {
      | 1 => "image-gallery single"
      | 2 => "image-gallery double"
      | 3 => "image-gallery triple"
      | _ => "image-gallery multiple"
      }

      let imageCount = imageFiles->Array.length
      let galleryLabel = switch imageCount {
      | 1 => "画像"
      | count => Int.toString(count) ++ " 枚の画像"
      }

      <div className={gridClass} role="group" ariaLabel={galleryLabel}>
        {imageFiles
        ->Array.mapWithIndex((file, idx) => {
          <ImageAttachment key={file.id ++ Int.toString(idx)} file={file} />
        })
        ->Preact.array}
      </div>
    } else {
      Preact.null
    }
  }
}

// ============================================================
// Note Actions Footer
// ============================================================

module NoteActions = {
  @jsx.component
  let make = (~noteId: string, ~noteHost: string, ~reactionAcceptance: option<SharedTypes.reactionAcceptance>=?) => {
    let (_, navigate) = Wouter.useLocation()
    let (isRenoting, setIsRenoting) = PreactHooks.useState(() => false)
    let (showEmojiPicker, setShowEmojiPicker) = PreactHooks.useState(() => false)
    let isLoggedIn = PreactSignals.value(AppState.isLoggedIn)
    let isReadOnly = AppState.isReadOnlyMode()

    let handleReply = (_: JsxEvent.Mouse.t) => {
      navigate("/notes/" ++ noteId ++ "/" ++ noteHost)
    }

    let handleRenote = (_: JsxEvent.Mouse.t) => {
      if isLoggedIn && !isReadOnly && !isRenoting {
        let _ = (async () => {
          setIsRenoting(_ => true)
          switch PreactSignals.value(AppState.client) {
          | Some(client) =>
            let renoteIdOpt = Some(noteId)
            let result = await client->Misskey.Notes.create("", ~renoteId=?renoteIdOpt, ())
            switch result {
            | Ok(_) => ToastState.showSuccess("リノートしました")
            | Error(msg) => ToastState.showError("リノートに失敗しました: " ++ msg)
            }
          | None => ToastState.showError("接続されていません")
          }
          setIsRenoting(_ => false)
        })()
      }
    }

    let handleEmojiSelect = (emoji: string) => {
      setShowEmojiPicker(_ => false)
      // Trigger reaction via ReactionBar logic
      let _ = (async () => {
        switch PreactSignals.value(AppState.client) {
        | Some(client) =>
          let result = await client->Misskey.Notes.react(noteId, emoji)
          switch result {
          | Ok(_) => ()
          | Error(msg) => ToastState.showError("リアクションに失敗しました: " ++ msg)
          }
        | None => ()
        }
      })()
    }

    <div className="note-actions">
      <button
        className="note-action-btn"
        onClick={handleReply}
        title="返信"
        type_="button"
        ariaLabel="返信"
      >
        <iconify-icon icon="tabler:arrow-back-up" />
      </button>
      <button
        className={"note-action-btn" ++ (if isRenoting { " loading" } else { "" })}
        onClick={handleRenote}
        title="リノート"
        type_="button"
        ariaLabel="リノート"
        disabled={isRenoting || !isLoggedIn || isReadOnly}
      >
        <iconify-icon icon="tabler:repeat" />
      </button>
      {if isLoggedIn && !isReadOnly {
        <>
          <button
            className="note-action-btn"
            onClick={_ => setShowEmojiPicker(_ => true)}
            title="リアクション"
            type_="button"
            ariaLabel="リアクションを追加"
          >
            <iconify-icon icon="tabler:plus" />
          </button>
          {if showEmojiPicker {
            switch reactionAcceptance {
            | Some(acceptance) =>
              <EmojiPicker
                onSelect={handleEmojiSelect}
                onClose={() => setShowEmojiPicker(_ => false)}
                reactionAcceptance={acceptance}
              />
            | None =>
              <EmojiPicker
                onSelect={handleEmojiSelect}
                onClose={() => setShowEmojiPicker(_ => false)}
              />
            }
          } else {
            Preact.null
          }}
        </>
      } else {
        Preact.null
      }}
      <button
        className="note-action-btn note-action-more"
        title="その他"
        type_="button"
        ariaLabel="その他"
      >
        <iconify-icon icon="tabler:dots" />
      </button>
    </div>
  }
}

// ============================================================
// Main Note Component
// ============================================================

// Internal component that renders a decoded note
module NoteView = {
  @jsx.component
  let make = (~note: NoteView.t, ~noteHost: option<string>=?) => {
    // Track render performance
    let _ = PerfMonitor.useRenderMetrics(~component="Note")
    let (_, navigate) = Wouter.useLocation()
    let localHost = PreactSignals.value(AppState.instanceName)
    // Use provided noteHost (e.g., from NotePage) or fall back to active account's host
    let effectiveHost = switch noteHost {
    | Some(h) => h
    | None => localHost
    }

    // Content warning state
    let (showContent, setShowContent) = PreactHooks.useState(() =>
      !NoteView.hasContentWarning(note)
    )

    let handleToggleCw = (_: JsxEvent.Mouse.t) => {
      setShowContent(prev => !prev)
    }

    let isPureRenote = NoteView.isPureRenote(note)

    let handleNoteClick = (e: JsxEvent.Mouse.t) => {
      // Don't navigate if clicking a link, button, or interactive element
      let target: Dom.element = e->JsxEvent.Mouse.target->Obj.magic
      let tagName: string = (target->Obj.magic)["tagName"]
      let isInteractive = tagName == "A" || tagName == "BUTTON" || tagName == "IMG" || tagName == "INPUT"
      // Check if target or parent is inside an interactive element
      let closest: Nullable.t<Dom.element> = (target->Obj.magic)["closest"]("a, button, .reaction-button, .lightbox-overlay, .sensitive-overlay, .image-attachment")
      if !isInteractive && Nullable.isNullable(closest) {
        navigate("/notes/" ++ note.id ++ "/" ++ effectiveHost)
      }
    }

    <article
      className="note note-clickable"
      role="article"
      ariaLabel={note.user.name ++ " のノート"}
      onClick={handleNoteClick}
    >
      // Reply parent (shown as compact, semi-transparent context)
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

      {
        // Show renote indicator
        if isPureRenote {
          <div
            className="renote-indicator" role="status" ariaLabel={note.user.name ++ " がリノート"}
          >
            <small> <MfmRenderer text={note.user.name} parseSimple=true /> {Preact.string(" がリノート")} </small>
          </div>
        } else {
          Preact.null
        }
      }

      <NoteHeader user={note.user} createdAt={note.createdAt} noteId={note.id} contextHost={effectiveHost} />

      <NoteContent note showContent onToggleCw={handleToggleCw} contextHost={effectiveHost} />

      {switch // Handle renote content
      note.renote {
      | Some(renoteData) if isPureRenote => // Render renoted note
        <div className="renoted-note renoted-note-clickable" onClick={e => {
          let target: Dom.element = e->JsxEvent.Mouse.target->Obj.magic
          let tagName: string = (target->Obj.magic)["tagName"]
          let isInteractive = tagName == "A" || tagName == "BUTTON" || tagName == "IMG" || tagName == "INPUT"
          let closest: Nullable.t<Dom.element> = (target->Obj.magic)["closest"]("a, button, .reaction-button, .lightbox-overlay, .sensitive-overlay, .image-attachment")
          if !isInteractive && Nullable.isNullable(closest) {
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
}

// Main entry point - accepts JSON.t and decodes
@jsx.component
let make = (~note: JSON.t) => {
  switch NoteDecoder.decode(note) {
  | Some(noteData) => <NoteView note={noteData} />
  | None => Preact.null
  }
}
