// SPDX-License-Identifier: MPL-2.0
// ImagePreloader.res - Image preloading utilities

// ============================================================
// Image Preloading
// ============================================================

type image

@new external createImage: unit => image = "Image"
@set external setImageSrc: (image, string) => unit = "src"

// Preload an image by creating an Image object and setting its src
let preloadImage = (url: string): unit => {
  let img = createImage()
  setImageSrc(img, url)
}
