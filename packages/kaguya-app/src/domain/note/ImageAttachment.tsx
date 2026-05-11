// SPDX-License-Identifier: MPL-2.0

import { useState } from 'preact/hooks'
import type { FileView } from '../file/fileView'
import { isImage } from '../file/fileView'
import { ImageLightbox } from './ImageLightbox'
import { t } from '../../infra/i18n'
import { proxyUrl } from '../../infra/mediaProxy'

type Props = {
  file: FileView
}

export function ImageAttachment({ file }: Props) {
  const [showSensitive, setShowSensitive] = useState(!file.isSensitive)
  const [showLightbox, setShowLightbox] = useState(false)
  const [imageLoaded, setImageLoaded] = useState(false)

  const thumbnailUrl = proxyUrl(file.thumbnailUrl ?? file.url)
  const fullUrl = proxyUrl(file.url)

  if (!isImage(file) || !file.url) return null

  return (
    <>
      <div
        class="image-attachment"
        role="button"
        tabIndex={showSensitive ? 0 : -1}
        aria-label={file.isSensitive && !showSensitive ? t('image.sensitive_aria') : `${t('image.enlarge')}: ${file.name}`}
      >
        {file.isSensitive && !showSensitive && (
          <div
            class="sensitive-overlay"
            onClick={() => setShowSensitive(true)}
            role="button"
            tabIndex={0}
            aria-label={t('image.show_sensitive')}
          >
            <div class="sensitive-warning" aria-hidden="true">
              <span class="sensitive-icon">⚠️</span>
              <span class="sensitive-text">{t('image.sensitive_label')}</span>
              <small class="sensitive-hint">{t('image.tap_to_show')}</small>
            </div>
          </div>
        )}
        {!imageLoaded && thumbnailUrl !== fullUrl && (
          <img
            class={file.isSensitive && !showSensitive ? 'image-sensitive-hidden' : 'image-placeholder'}
            src={thumbnailUrl}
            width={file.width?.toString()}
            height={file.height?.toString()}
            alt=""
            aria-hidden="true"
            role="presentation"
          />
        )}
        <img
          class={
            file.isSensitive && !showSensitive ? 'image-sensitive-hidden'
            : imageLoaded ? 'image-content image-loaded'
            : 'image-content image-loading'
          }
          src={fullUrl}
          width={file.width?.toString()}
          height={file.height?.toString()}
          alt={file.name}
          loading="lazy"
          onLoad={() => setImageLoaded(true)}
          onClick={e => {
            e.stopPropagation()
            if (showSensitive) setShowLightbox(true)
          }}
          style={{ cursor: showSensitive ? 'zoom-in' : 'default' }}
          role="img"
          aria-hidden={file.isSensitive && !showSensitive}
        />
      </div>
      {showLightbox && (
        <ImageLightbox url={fullUrl} name={file.name} onClose={() => setShowLightbox(false)} />
      )}
    </>
  )
}
