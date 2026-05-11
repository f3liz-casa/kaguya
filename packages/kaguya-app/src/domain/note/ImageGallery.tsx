// SPDX-License-Identifier: MPL-2.0

import { useState } from 'preact/hooks'
import type { FileView } from '../file/fileView'
import { isImage } from '../file/fileView'
import { ImageAttachment } from './ImageAttachment'
import { t } from '../../infra/i18n'

type Props = {
  files: FileView[]
}

const maxVisibleImages = 2

export function ImageGallery({ files }: Props) {
  const imageFiles = files.filter(isImage)
  const totalCount = imageFiles.length
  const [expanded, setExpanded] = useState(false)

  if (totalCount === 0) return null

  const visibleFiles = expanded || totalCount <= maxVisibleImages ? imageFiles : imageFiles.slice(0, maxVisibleImages)
  const hiddenCount = totalCount - visibleFiles.length

  const gridClass = visibleFiles.length === 1 ? 'image-gallery single'
    : visibleFiles.length === 2 ? 'image-gallery double'
    : visibleFiles.length === 3 ? 'image-gallery triple'
    : 'image-gallery multiple'

  const galleryLabel = totalCount === 1 ? t('image.gallery_single') : `${totalCount}${t('image.gallery_count')}`

  return (
    <div role="group" aria-label={galleryLabel}>
      <div class={gridClass}>
        {visibleFiles.map((file, idx) => (
          <ImageAttachment key={file.id + idx} file={file} />
        ))}
      </div>
      {hiddenCount > 0 && (
        <button
          class="show-more-files"
          type="button"
          onClick={e => { e.stopPropagation(); setExpanded(true) }}
        >
          Show more ({hiddenCount} file(s))
        </button>
      )}
    </div>
  )
}
