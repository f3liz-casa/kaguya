// SPDX-License-Identifier: MPL-2.0

import { useEffect } from 'preact/hooks'
import { t } from '../../infra/i18n'

type Props = {
  url: string
  name: string
  onClose: () => void
}

export function ImageLightbox({ url, name, onClose }: Props) {
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', handleEscape)
    return () => document.removeEventListener('keydown', handleEscape)
  }, [onClose])

  useEffect(() => {
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => { document.body.style.overflow = prev }
  }, [])

  return (
    <div
      class="lightbox-overlay"
      onClick={() => onClose()}
      role="dialog"
      aria-modal={true}
      aria-label={t('image.viewer')}
    >
      <div class="lightbox-content" onClick={e => e.stopPropagation()}>
        <button class="lightbox-close" onClick={() => onClose()} aria-label={t('image.close_viewer')} type="button">
          ×
        </button>
        <img class="lightbox-image" src={url} alt={name} onClick={() => onClose()} role="img" />
      </div>
    </div>
  )
}
