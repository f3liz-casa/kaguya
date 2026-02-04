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
      ariaLabel="Image viewer"
    >
      <div className="lightbox-content" onClick={e => e->JsxEvent.Mouse.stopPropagation}>
        <button
          className="lightbox-close"
          onClick={_ => onClose()}
          ariaLabel="Close image viewer"
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

    // Calculate aspect ratio for proper display
    let aspectRatio = FileView.aspectRatio(file)

    // Only render if it's an image
    if FileView.isImage(file) && file.url != "" {
      // Create style object for aspect ratio
      let imageStyle = switch aspectRatio {
      | Some(ratio) => Style.make(~aspectRatio=Float.toString(ratio), ())
      | None => Style.make()
      }

      let cursorStyle = Style.make(~cursor=showSensitive ? "zoom-in" : "default", ())

      <>
        <div
          className="image-attachment"
          style={imageStyle}
          role="button"
          tabIndex={showSensitive ? 0 : -1}
          ariaLabel={file.isSensitive && !showSensitive
            ? "Sensitive image, click to reveal"
            : "Click to view full image: " ++ file.name}
        >
          {if file.isSensitive && !showSensitive {
            <div
              className="sensitive-overlay"
              onClick={_ => setShowSensitive(_ => true)}
              role="button"
              tabIndex={0}
              ariaLabel="Reveal sensitive content"
            >
              <div className="sensitive-warning" ariaHidden={true}>
                <span className="sensitive-icon"> {Preact.string("⚠️")} </span>
                <span className="sensitive-text"> {Preact.string("Sensitive content")} </span>
                <small className="sensitive-hint"> {Preact.string("Click to reveal")} </small>
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
      | 1 => "Image attachment"
      | count => Int.toString(count) ++ " image attachments"
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
// Main Note Component
// ============================================================

// Internal component that renders a decoded note
module NoteView = {
  @jsx.component
  let make = (~note: NoteView.t) => {
    // Track render performance
    let _ = PerfMonitor.useRenderMetrics(~component="Note")

    // Content warning state
    let (showContent, setShowContent) = PreactHooks.useState(() =>
      !NoteView.hasContentWarning(note)
    )

    let handleToggleCw = (_: JsxEvent.Mouse.t) => {
      setShowContent(prev => !prev)
    }

    let isPureRenote = NoteView.isPureRenote(note)

    <article className="note" role="article" ariaLabel={"Note by " ++ note.user.name}>
      {
        // Show renote indicator
        if isPureRenote {
          <div
            className="renote-indicator" role="status" ariaLabel={note.user.name ++ " renoted this"}
          >
            <small> {Preact.string(note.user.name ++ " renoted")} </small>
          </div>
        } else {
          Preact.null
        }
      }

      <NoteHeader user={note.user} createdAt={note.createdAt} />

      <NoteContent note showContent onToggleCw={handleToggleCw} />

      {switch // Handle renote content
      note.renote {
      | Some(renoteData) if isPureRenote => // Render renoted note
        <div className="renoted-note">
          <NoteHeader user={renoteData.user} createdAt={renoteData.createdAt} />
          {switch renoteData.text {
          | Some(t) =>
            <div className="note-text">
              <MfmRenderer text={t} />
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
