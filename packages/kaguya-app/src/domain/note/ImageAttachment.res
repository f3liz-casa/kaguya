// SPDX-License-Identifier: MPL-2.0

@jsx.component
let make = (~file: FileView.t) => {
  let (showSensitive, setShowSensitive) = PreactHooks.useState(() => !file.isSensitive)
  let (showLightbox, setShowLightbox) = PreactHooks.useState(() => false)
  let (imageLoaded, setImageLoaded) = PreactHooks.useState(() => false)

  let thumbnailUrl = file.thumbnailUrl->Option.getOr(file.url)

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
        {if !imageLoaded && thumbnailUrl != file.url {
          <img
            className={file.isSensitive && !showSensitive
              ? "image-sensitive-hidden"
              : "image-placeholder"}
            src={thumbnailUrl}
            width=?{file.width->Option.map(v => Int.toString(v))}
            height=?{file.height->Option.map(v => Int.toString(v))}
            alt=""
            ariaHidden={true}
            role="presentation"
          />
        } else {
          Preact.null
        }}
        <img
          className={if file.isSensitive && !showSensitive {
            "image-sensitive-hidden"
          } else if imageLoaded {
            "image-content image-loaded"
          } else {
            "image-content image-loading"
          }}
          src={file.url}
          width=?{file.width->Option.map(v => Int.toString(v))}
          height=?{file.height->Option.map(v => Int.toString(v))}
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
