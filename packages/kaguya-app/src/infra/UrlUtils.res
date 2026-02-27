// SPDX-License-Identifier: MPL-2.0

// URL Parsers

// Normalize instance origin (ensure https:// prefix)
let normalizeOrigin = (input: string): string => {
  let trimmed = input->String.trim
  if trimmed->String.startsWith("https://") || trimmed->String.startsWith("http://") {
    trimmed
  } else {
    "https://" ++ trimmed
  }
}

// Extract hostname from origin URL
let hostnameFromOrigin = (origin: string): string => {
  try {
    let url = URL.make(origin)
    url->URL.hostname
  } catch {
  | _ => origin
  }
}

// Avatar URL Handling

// Fix avatar URLs by adding &static=1 parameter for proxy URLs
let fixAvatarUrl = (url: string): string => {
  if url->String.includes("/proxy/avatar.webp?") && !(url->String.includes("&static=1")) {
    url ++ "&static=1"
  } else {
    url
  }
}

// Image URL Handling

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

// MIME Type Checking

let isImageMimeType = (mimeType: string): bool => mimeType->String.startsWith("image/")
let isVideoMimeType = (mimeType: string): bool => mimeType->String.startsWith("video/")
let isAudioMimeType = (mimeType: string): bool => mimeType->String.startsWith("audio/")
