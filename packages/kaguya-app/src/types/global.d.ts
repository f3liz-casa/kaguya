// SPDX-License-Identifier: MPL-2.0
// Global type declarations for web components and build constants

/// <reference types="vite/client" />

declare const __BUILD_TIME__: string

// Extend Preact's JSX to include the iconify-icon web component.
// With jsxImportSource: "preact", JSX types live in preact/jsx-runtime.
import type { JSX as PreactJSX } from 'preact'

declare module 'preact' {
  namespace JSX {
    interface IntrinsicElements {
      'iconify-icon': PreactJSX.HTMLAttributes<HTMLElement> & {
        icon: string
        width?: string | number
        height?: string | number
        inline?: boolean
      }
    }
  }
}
