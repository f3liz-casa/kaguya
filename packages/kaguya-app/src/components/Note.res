// SPDX-License-Identifier: MPL-2.0
// Note.res - Note display component

// Helper to extract string field from JSON object
let getStringField = (obj: Dict.t<JSON.t>, field: string): option<string> => {
  obj->Dict.get(field)->Option.flatMap(JSON.Decode.string)
}

// Helper to fix avatar URLs - add &static=1 if it's a proxy URL without it
let fixAvatarUrl = (url: string): string => {
  if url->String.includes("/proxy/avatar.webp?") && !(url->String.includes("&static=1")) {
    url ++ "&static=1"
  } else {
    url
  }
}

// Helper to extract optional string field
let getOptionalStringField = (obj: Dict.t<JSON.t>, field: string): option<string> => {
  switch obj->Dict.get(field) {
  | Some(value) =>
    switch value {
    | JSON.Null => None
    | _ => JSON.Decode.string(value)
    }
  | None => None
  }
}

// Helper to get user display info from note
let getUserInfo = (noteObj: Dict.t<JSON.t>): (string, string, string) => {
  switch noteObj->Dict.get("user")->Option.flatMap(JSON.Decode.object) {
  | Some(user) => {
      let name = getOptionalStringField(user, "name")->Option.getOr(
        getStringField(user, "username")->Option.getOr("Unknown"),
      )
      let username = getStringField(user, "username")->Option.getOr("unknown")
      let avatarUrl = getStringField(user, "avatarUrl")->Option.getOr("")->fixAvatarUrl
      (name, username, avatarUrl)
    }
  | None => ("Unknown", "unknown", "")
  }
}

// Helper to extract and cache emojis from note
let extractEmojis = (noteObj: Dict.t<JSON.t>): unit => {
  // Check reactionEmojis field (contains emojis used as reactions on the note)
  switch noteObj->Dict.get("reactionEmojis")->Option.flatMap(JSON.Decode.object) {
  | Some(reactionEmojis) => {
      // Convert to string dict
      let emojiDict = Dict.make()
      
      reactionEmojis->Dict.toArray->Array.forEach(((name, urlJson)) => {
        switch urlJson->JSON.Decode.string {
        | Some(url) => emojiDict->Dict.set(name, url)
        | None => ()
        }
      })
      
      // Add all at once (more efficient)
      if emojiDict->Dict.keysToArray->Array.length > 0 {
        EmojiStore.addEmojis(emojiDict)
      }
    }
  | None => ()
  }
  
  // Check emojis field (contains custom emojis used in the note text)
  // This is an OBJECT (dict), not an array, mapping emoji name to URL
  switch noteObj->Dict.get("emojis")->Option.flatMap(JSON.Decode.object) {
  | Some(emojisDict) => {
      // Convert to string dict
      let emojiDict = Dict.make()
      
      emojisDict->Dict.toArray->Array.forEach(((name, urlJson)) => {
        switch urlJson->JSON.Decode.string {
        | Some(url) => emojiDict->Dict.set(name, url)
        | None => ()
        }
      })
      
      // Add all at once (more efficient)
      if emojiDict->Dict.keysToArray->Array.length > 0 {
        EmojiStore.addEmojis(emojiDict)
      }
    }
  | None => ()
  }
}

// Format relative time
let formatRelativeTime = (dateStr: string): string => {
  try {
    let date = Date.fromString(dateStr)
    let now = Date.now()
    let diffMs = now -. Date.getTime(date)
    let diffSec = diffMs /. 1000.0
    let diffMin = diffSec /. 60.0
    let diffHour = diffMin /. 60.0
    let diffDay = diffHour /. 24.0

    if diffSec < 60.0 {
      "now"
    } else if diffMin < 60.0 {
      Int.toString(Float.toInt(diffMin)) ++ "m"
    } else if diffHour < 24.0 {
      Int.toString(Float.toInt(diffHour)) ++ "h"
    } else if diffDay < 7.0 {
      Int.toString(Float.toInt(diffDay)) ++ "d"
    } else {
      // Format as date
      let month = Date.getMonth(date) + 1
      let day = Date.getDate(date)
      Int.toString(month) ++ "/" ++ Int.toString(day)
    }
  } catch {
  | _ => ""
  }
}

// Helper to check if a file is an image based on MIME type
let isImageFile = (fileType: string): bool => {
  fileType->String.startsWith("image/")
}

// Helper to extract files from note
let getFiles = (noteObj: Dict.t<JSON.t>): array<JSON.t> => {
  switch noteObj->Dict.get("files")->Option.flatMap(JSON.Decode.array) {
  | Some(files) => files
  | None => []
  }
}

// Helper to extract reactions from note
let getReactions = (noteObj: Dict.t<JSON.t>): Dict.t<int> => {
  switch noteObj->Dict.get("reactions")->Option.flatMap(JSON.Decode.object) {
  | Some(reactionsObj) => {
      let reactionsDict = Dict.make()
      reactionsObj->Dict.toArray->Array.forEach(((reaction, countJson)) => {
        switch countJson->JSON.Decode.float {
        | Some(countFloat) => {
            let count = Float.toInt(countFloat)
            if count > 0 {
              reactionsDict->Dict.set(reaction, count)
            }
          }
        | None => ()
        }
      })
      reactionsDict
    }
  | None => Dict.make()
  }
}

// Helper to extract reaction acceptance from note
let getReactionAcceptance = (noteObj: Dict.t<JSON.t>): option<[
  | #likeOnly
  | #likeOnlyForRemote
  | #nonSensitiveOnly
  | #nonSensitiveOnlyForLocalLikeOnlyForRemote
]> => {
  switch noteObj->Dict.get("reactionAcceptance")->Option.flatMap(JSON.Decode.string) {
  | Some("likeOnly") => Some(#likeOnly)
  | Some("likeOnlyForRemote") => Some(#likeOnlyForRemote)
  | Some("nonSensitiveOnly") => Some(#nonSensitiveOnly)
  | Some("nonSensitiveOnlyForLocalLikeOnlyForRemote") => Some(#nonSensitiveOnlyForLocalLikeOnlyForRemote)
  | _ => None
  }
}

// Helper to extract reactionEmojis dict from note
let getReactionEmojis = (noteObj: Dict.t<JSON.t>): Dict.t<string> => {
  switch noteObj->Dict.get("reactionEmojis")->Option.flatMap(JSON.Decode.object) {
  | Some(reactionEmojis) => {
      let emojiDict = Dict.make()
      reactionEmojis->Dict.toArray->Array.forEach(((name, urlJson)) => {
        switch urlJson->JSON.Decode.string {
        | Some(url) => emojiDict->Dict.set(name, url)
        | None => ()
        }
      })
      emojiDict
    }
  | None => Dict.make()
  }
}

// Helper to get image dimensions
let getImageDimensions = (fileObj: Dict.t<JSON.t>): (option<int>, option<int>) => {
  switch fileObj->Dict.get("properties")->Option.flatMap(JSON.Decode.object) {
  | Some(props) => {
      let width = props->Dict.get("width")->Option.flatMap(value => 
        switch JSON.Decode.float(value) {
        | Some(f) => Some(Float.toInt(f))
        | None => None
        }
      )
      let height = props->Dict.get("height")->Option.flatMap(value => 
        switch JSON.Decode.float(value) {
        | Some(f) => Some(Float.toInt(f))
        | None => None
        }
      )
      (width, height)
    }
  | None => (None, None)
  }
}

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
        <img 
          className="lightbox-image"
          src={url}
          alt={name}
          onClick={_ => onClose()}
          role="img"
        />
      </div>
    </div>
  }
}

// Component for rendering a single image
module ImageAttachment = {
  @jsx.component
  let make = (~file: JSON.t, ~isSensitive: bool) => {
    let (showSensitive, setShowSensitive) = PreactHooks.useState(() => !isSensitive)
    let (showLightbox, setShowLightbox) = PreactHooks.useState(() => false)
    let (imageLoaded, setImageLoaded) = PreactHooks.useState(() => false)
    
    switch file->JSON.Decode.object {
    | Some(fileObj) => {
        let url = getStringField(fileObj, "url")->Option.getOr("")
        let thumbnailUrl = getOptionalStringField(fileObj, "thumbnailUrl")->Option.getOr(url)
        let name = getStringField(fileObj, "name")->Option.getOr("image")
        let fileType = getStringField(fileObj, "type")->Option.getOr("")
        let (width, height) = getImageDimensions(fileObj)
        
        // Calculate aspect ratio for proper display
        let aspectRatio = switch (width, height) {
        | (Some(w), Some(h)) if h > 0 => Some(Float.fromInt(w) /. Float.fromInt(h))
        | _ => None
        }
        
        // Only render if it's an image
        if isImageFile(fileType) && url != "" {
            // Create style object for aspect ratio
            let imageStyle = switch aspectRatio {
            | Some(ratio) => 
                Style.make(~aspectRatio=Float.toString(ratio), ())
            | None => Style.make(())
            }
            
            let cursorStyle = Style.make(
              ~cursor=showSensitive ? "zoom-in" : "default",
              (),
            )
            
            <>
            <div 
              className="image-attachment"
              style={imageStyle}
              role="button"
              tabIndex={showSensitive ? 0 : -1}
              ariaLabel={isSensitive && !showSensitive 
                ? "Sensitive image, click to reveal" 
                : "Click to view full image: " ++ name}
            >
              {if isSensitive && !showSensitive {
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
              {if !imageLoaded && thumbnailUrl != url {
                <img 
                  className={isSensitive && !showSensitive ? "image-sensitive-hidden" : "image-placeholder"}
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
                className={
                  if isSensitive && !showSensitive {
                    "image-sensitive-hidden"
                  } else if imageLoaded {
                    "image-content image-loaded"
                  } else {
                    "image-content image-loading"
                  }
                }
                src={url}
                alt={name}
                loading=#"lazy"
                onLoad={_ => setImageLoaded(_ => true)}
                onClick={e => {
                  e->JsxEvent.Mouse.stopPropagation
                  if showSensitive {
                    setShowLightbox(_ => true)
                  }
                }}
                style={cursorStyle}
                role="img"
                ariaHidden={isSensitive && !showSensitive}
              />
            </div>
            {if showLightbox {
              <ImageLightbox url={url} name={name} onClose={() => setShowLightbox(_ => false)} />
            } else {
              Preact.null
            }}
          </>
        } else {
          Preact.null
        }
      }
    | None => Preact.null
    }
  }
}

// Component for rendering image gallery
module ImageGallery = {
  @jsx.component
  let make = (~files: array<JSON.t>) => {
    // Filter only image files
    let imageFiles = files->Array.filter(file => {
      switch file->JSON.Decode.object {
      | Some(fileObj) => {
          let fileType = getStringField(fileObj, "type")->Option.getOr("")
          isImageFile(fileType)
        }
      | None => false
      }
    })
    
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
      
      <div 
        className={gridClass}
        role="group"
        ariaLabel={galleryLabel}
      >
        {imageFiles->Array.mapWithIndex((file, idx) => {
          let isSensitive = switch file->JSON.Decode.object {
          | Some(fileObj) => {
              switch fileObj->Dict.get("isSensitive")->Option.flatMap(JSON.Decode.bool) {
              | Some(sensitive) => sensitive
              | None => false
              }
            }
          | None => false
          }
          
          <ImageAttachment key={Int.toString(idx)} file={file} isSensitive={isSensitive} />
        })->Preact.array}
      </div>
    } else {
      Preact.null
    }
  }
}

@jsx.component
let make = (~note: JSON.t) => {
  // Track render performance
  let _ = PerfMonitor.useRenderMetrics(~component="Note")
  
  switch note->JSON.Decode.object {
  | Some(noteObj) => {
      // Extract emojis from note and add to cache
      extractEmojis(noteObj)
      
      let (name, username, avatarUrl) = getUserInfo(noteObj)
      let text = getOptionalStringField(noteObj, "text")
      let cw = getOptionalStringField(noteObj, "cw")
      let createdAt = getStringField(noteObj, "createdAt")->Option.getOr("")
      let relativeTime = formatRelativeTime(createdAt)
      let files = getFiles(noteObj)
      let noteId = getStringField(noteObj, "id")->Option.getOr("")
      let reactions = getReactions(noteObj)
      let reactionEmojis = getReactionEmojis(noteObj)
      let myReaction = getOptionalStringField(noteObj, "myReaction")
      let reactionAcceptance = getReactionAcceptance(noteObj)

      // Check for content warning
      let (showContent, setShowContent) = PreactHooks.useState(() => cw->Option.isNone)

      let handleToggleCw = (_: JsxEvent.Mouse.t) => {
        setShowContent(prev => !prev)
      }

      // Check if this is a renote
      let renote = noteObj->Dict.get("renote")->Option.flatMap(JSON.Decode.object)
      
      // Extract emojis from renote too
      renote->Option.forEach(extractEmojis)
      
      let isRenote = renote->Option.isSome && text->Option.isNone

      <article className="note" role="article" ariaLabel={"Note by " ++ name}>
        {// Show renote indicator
        if isRenote {
          <div className="renote-indicator" role="status" ariaLabel={name ++ " renoted this"}>
            <small> {Preact.string(name ++ " renoted")} </small>
          </div>
        } else {
          Preact.null
        }}
        <div className="note-header">
          {if avatarUrl != "" {
            <img 
              className="avatar" 
              src={avatarUrl} 
              alt={username ++ "'s avatar"}
              onError={e => {
                let target = JsxEventU.Media.target(e)
                HtmlElement.setDisplay(target, "none")
              }}
              role="img"
            />
          } else {
            <div className="avatar-placeholder" ariaLabel={username ++ "'s avatar"} role="img" />
          }}
          <div className="note-author">
            <span className="display-name"> {Preact.string(name)} </span>
            <span className="username"> {Preact.string("@" ++ username)} </span>
          </div>
          <time className="note-time" dateTime={createdAt}> {Preact.string(relativeTime)} </time>
        </div>
        <div className="note-content" role="region" ariaLabel="Note content">
          {// Content warning handling
          switch cw {
          | Some(cwText) =>
            <>
              <p className="content-warning" role="alert"> {Preact.string(cwText)} </p>
              <button 
                className="cw-toggle secondary outline" 
                onClick={handleToggleCw}
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
            <>
              {switch text {
              | Some(t) =>
                <div className="note-text"> <MfmRenderer text={t} /> </div>
              | None =>
                // If renote, show the renoted content
                switch renote {
                | Some(renoteObj) => {
                    let (rName, rUsername, rAvatarUrl) = getUserInfo(renoteObj)
                    let rText = getOptionalStringField(renoteObj, "text")
                    let rFiles = getFiles(renoteObj)
                    let rNoteId = getStringField(renoteObj, "id")->Option.getOr("")
                    let rReactions = getReactions(renoteObj)
                    let rReactionEmojis = getReactionEmojis(renoteObj)
                    let rMyReaction = getOptionalStringField(renoteObj, "myReaction")
                    let rReactionAcceptance = getReactionAcceptance(renoteObj)

                    <div className="renoted-note">
                      <div className="note-header">
                        {if rAvatarUrl != "" {
                          <img className="avatar small" src={rAvatarUrl} alt={rUsername} />
                        } else {
                          <div className="avatar-placeholder small" />
                        }}
                        <div className="note-author">
                          <span className="display-name"> {Preact.string(rName)} </span>
                          <span className="username"> {Preact.string("@" ++ rUsername)} </span>
                        </div>
                      </div>
                      {switch rText {
                      | Some(t) =>
                        <div className="note-text"> <MfmRenderer text={t} /> </div>
                      | None => Preact.null
                      }}
                      <ImageGallery files={rFiles} />
                      <ReactionBar
                        noteId={rNoteId}
                        reactions={rReactions}
                        reactionEmojis={rReactionEmojis}
                        myReaction={rMyReaction}
                        reactionAcceptance={rReactionAcceptance}
                      />
                    </div>
                  }
                | None => Preact.null
                }
              }}
              {if !isRenote {
                <>
                  <ImageGallery files={files} />
                  <ReactionBar
                    noteId={noteId}
                    reactions={reactions}
                    reactionEmojis={reactionEmojis}
                    myReaction={myReaction}
                    reactionAcceptance={reactionAcceptance}
                  />
                </>
              } else {
                <ImageGallery files={files} />
              }}
            </>
          } else {
            Preact.null
          }}
        </div>
      </article>
    }
  | None => Preact.null
  }
}
