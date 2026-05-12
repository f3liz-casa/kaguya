// SPDX-License-Identifier: MPL-2.0

import { effect, type ReadonlySignal } from '@preact/signals-core'

export function svelteSignal<T>(source: ReadonlySignal<T>): { readonly value: T } {
  let v = $state(source.peek())
  $effect(() => effect(() => { v = source.value }))
  return { get value() { return v } }
}
