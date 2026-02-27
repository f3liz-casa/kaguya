// SPDX-License-Identifier: MPL-2.0

// Image Preloading

type image

@new external createImage: unit => image = "Image"
@set external setImageSrc: (image, string) => unit = "src"
@set external setOnLoad: (image, unit => unit) => unit = "onload"
@set external setOnError: (image, unit => unit) => unit = "onerror"

// Preload an image by creating an Image object and setting its src
let preloadImage = (url: string): unit => {
  let img = createImage()
  setImageSrc(img, url)
}

// Preload an image and return a promise that resolves when loaded (or on error/timeout)
let preloadImageAsync = (url: string): promise<unit> => {
  Promise.make((resolve, _reject) => {
    let img = createImage()
    let resolved = ref(false)
    let finish = () => {
      if !resolved.contents {
        resolved := true
        resolve()
      }
    }
    setOnLoad(img, finish)
    setOnError(img, finish)
    // Fallback timeout: don't block forever on slow/broken images
    let _ = SetTimeout.make(finish, 3000)
    setImageSrc(img, url)
  })
}
