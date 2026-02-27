// SPDX-License-Identifier: MPL-2.0

let maxVisibleImages = 2

@jsx.component
let make = (~files: array<FileView.t>) => {
  let imageFiles = files->Array.filter(FileView.isImage)
  let totalCount = imageFiles->Array.length
  let (expanded, setExpanded) = PreactHooks.useState(() => false)

  if totalCount > 0 {
    let visibleFiles = if expanded || totalCount <= maxVisibleImages {
      imageFiles
    } else {
      imageFiles->Array.slice(~start=0, ~end=maxVisibleImages)
    }

    let visibleCount = visibleFiles->Array.length

    let gridClass = switch visibleCount {
    | 1 => "image-gallery single"
    | 2 => "image-gallery double"
    | 3 => "image-gallery triple"
    | _ => "image-gallery multiple"
    }

    let galleryLabel = switch totalCount {
    | 1 => "画像"
    | count => Int.toString(count) ++ " 枚の画像"
    }

    let hiddenCount = totalCount - visibleCount

    <div role="group" ariaLabel={galleryLabel}>
      <div className={gridClass}>
        {visibleFiles
        ->Array.mapWithIndex((file, idx) => {
          <ImageAttachment key={file.id ++ Int.toString(idx)} file />
        })
        ->Preact.array}
      </div>
      {if hiddenCount > 0 {
        <button
          className="show-more-files"
          type_="button"
          onClick={e => {
            e->JsxEvent.Mouse.stopPropagation
            setExpanded(_ => true)
          }}
        >
          {Preact.string("Show more (" ++ Int.toString(hiddenCount) ++ " file(s))")}
        </button>
      } else {
        Preact.null
      }}
    </div>
  } else {
    Preact.null
  }
}
