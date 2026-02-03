// SPDX-License-Identifier: MPL-2.0
// IntersectionObserver.res - IntersectionObserver bindings

// ============================================================
// IntersectionObserver Types
// ============================================================

type intersectionObserverEntry = {
  isIntersecting: bool,
}

type intersectionObserver

type observerOptions = {
  threshold: float,
}

// ============================================================
// IntersectionObserver Bindings
// ============================================================

@new
external make: (
  array<intersectionObserverEntry> => unit,
  observerOptions,
) => intersectionObserver = "IntersectionObserver"

@send
external observe: (intersectionObserver, Dom.element) => unit = "observe"

@send
external unobserve: (intersectionObserver, Dom.element) => unit = "unobserve"

@send
external disconnect: intersectionObserver => unit = "disconnect"

// ============================================================
// Helper Functions
// ============================================================

let makeObserver = (
  element: Dom.element,
  callback: unit => unit,
  ~threshold: float=0.1,
  (),
): (intersectionObserver, unit => unit) => {
  let observer = make(
    entries => {
      switch entries->Array.get(0) {
      | Some(entry) =>
        if entry.isIntersecting {
          callback()
        }
      | None => ()
      }
    },
    {threshold: threshold},
  )

  observe(observer, element)

  let cleanup = () => {
    unobserve(observer, element)
    disconnect(observer)
  }

  (observer, cleanup)
}
