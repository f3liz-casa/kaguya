// SPDX-License-Identifier: MPL-2.0

import { isImageMimeType, isVideoMimeType, isAudioMimeType } from '../../infra/urlUtils'
import { asObj, getString, getBool, getFloat, getObj } from '../../infra/jsonUtils'

export type FileView = {
  id: string
  name: string
  url: string
  thumbnailUrl: string | undefined
  type: string
  isSensitive: boolean
  width: number | undefined
  height: number | undefined
}

export function isImage(file: FileView): boolean {
  return isImageMimeType(file.type)
}

export function isVideo(file: FileView): boolean {
  return isVideoMimeType(file.type)
}

export function isAudio(file: FileView): boolean {
  return isAudioMimeType(file.type)
}

export function displayUrl(file: FileView): string {
  return file.thumbnailUrl ?? file.url
}

export function aspectRatio(file: FileView): number | undefined {
  if (file.width && file.height && file.height > 0) {
    return file.width / file.height
  }
  return undefined
}

export function decode(json: unknown): FileView | undefined {
  const obj = asObj(json)
  if (!obj) return undefined

  const id = getString(obj, 'id')
  const url = getString(obj, 'url')
  if (!id || !url) return undefined

  const props = getObj(obj, 'properties')
  const width = props ? getFloat(props, 'width') : undefined
  const height = props ? getFloat(props, 'height') : undefined

  return {
    id,
    name: getString(obj, 'name') ?? '',
    url,
    thumbnailUrl: getString(obj, 'thumbnailUrl') ?? undefined,
    type: getString(obj, 'type') ?? '',
    isSensitive: getBool(obj, 'isSensitive') ?? false,
    width: width !== undefined ? Math.floor(width) : undefined,
    height: height !== undefined ? Math.floor(height) : undefined,
  }
}
