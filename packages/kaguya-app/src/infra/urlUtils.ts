// SPDX-License-Identifier: MPL-2.0

export function normalizeOrigin(input: string): string {
  const trimmed = input.trim()
  if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) return trimmed
  return 'https://' + trimmed
}

export function hostnameFromOrigin(origin: string): string {
  try {
    return new URL(origin).hostname
  } catch {
    return origin
  }
}

export function fixAvatarUrl(url: string): string {
  if (url.includes('/proxy/avatar.webp?') && !url.includes('&static=1')) {
    return url + '&static=1'
  }
  return url
}

export function isImageUrl(url: string): boolean {
  const lower = url.toLowerCase()
  return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') ||
    lower.endsWith('.gif') || lower.endsWith('.webp') || lower.endsWith('.bmp') || lower.endsWith('.svg')
}

export function isImageMimeType(mimeType: string): boolean {
  return mimeType.startsWith('image/')
}

export function isVideoMimeType(mimeType: string): boolean {
  return mimeType.startsWith('video/')
}

export function isAudioMimeType(mimeType: string): boolean {
  return mimeType.startsWith('audio/')
}
