// SPDX-License-Identifier: MPL-2.0
// Thin wouter-compatible shim backed by preact-iso routing primitives.

import { useLocation as useIsoLocation } from 'preact-iso'
import type { ComponentChildren } from 'preact'

export { LocationProvider, Router } from 'preact-iso'

/** Returns [currentPath, navigate] — same shape as wouter's useLocation(). */
export function useLocation(): [string, (path: string) => void] {
  const loc = useIsoLocation()
  return [loc.path, loc.route]
}

/** Returns only the navigate function. */
export function useNavigate(): (path: string) => void {
  return useIsoLocation().route
}

type LinkProps = {
  href: string
  class?: string
  children: ComponentChildren
  onClick?: (e: MouseEvent) => void
}

/**
 * Client-side anchor that calls navigate() for left-clicks without
 * modifier keys, letting the browser handle everything else.
 */
export function Link({ href, class: className, children, onClick }: LinkProps) {
  const navigate = useNavigate()
  return (
    <a
      href={href}
      class={className}
      onClick={(e) => {
        const modified = e.ctrlKey || e.metaKey || e.altKey || e.shiftKey
        if (!modified && e.button === 0) {
          e.preventDefault()
          onClick?.(e)
          navigate(href)
        }
      }}
    >
      {children}
    </a>
  )
}
