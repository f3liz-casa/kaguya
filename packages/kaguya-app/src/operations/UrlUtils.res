// SPDX-License-Identifier: MPL-2.0
// UrlUtils.res - URL manipulation and normalization utilities

// ============================================================
// Avatar URL Handling
// ============================================================

// Fix avatar URLs by adding &static=1 parameter for proxy URLs
// This prevents animated avatars from causing performance issues
// Only applies to URLs that go through the Misskey proxy
let fixAvatarUrl = (url: string): string => {
  if url->String.includes("/proxy/avatar.webp?") && !(url->String.includes("&static=1")) {
    url ++ "&static=1"
  } else {
    url
  }
}

// ============================================================
// Image URL Handling
// ============================================================

// Check if a URL is an image based on file extension
let isImageUrl = (url: string): bool => {
  let lowerUrl = url->String.toLowerCase
  lowerUrl->String.endsWith(".jpg") ||
  lowerUrl->String.endsWith(".jpeg") ||
  lowerUrl->String.endsWith(".png") ||
  lowerUrl->String.endsWith(".gif") ||
  lowerUrl->String.endsWith(".webp") ||
  lowerUrl->String.endsWith(".bmp") ||
  lowerUrl->String.endsWith(".svg")
}

// ============================================================
// MIME Type Checking
// ============================================================

// Check if a file type is an image based on MIME type
let isImageMimeType = (mimeType: string): bool => {
  mimeType->String.startsWith("image/")
}

// Check if a file type is a video based on MIME type
let isVideoMimeType = (mimeType: string): bool => {
  mimeType->String.startsWith("video/")
}

// Check if a file type is audio based on MIME type
let isAudioMimeType = (mimeType: string): bool => {
  mimeType->String.startsWith("audio/")
}
