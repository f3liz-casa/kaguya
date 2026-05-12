// SPDX-License-Identifier: MPL-2.0

import { computed as coreComputed, effect, type ReadonlySignal } from '@preact/signals-core'

/**
 * signals-core の ReadonlySignal を Svelte 5 の reactive view に変換する bridge。
 * source の値が更新されると `value` getter が最新を返す。
 */
export function svelteSignal<T>(source: ReadonlySignal<T>): { readonly value: T } {
  let v = $state(source.peek())
  $effect(() => effect(() => { v = source.value }))
  return { get value() { return v } }
}

/**
 * source signal を fn で transform した derived view。
 * 内部で signals-core の `computed` を使うので memoization 効く（同 input なら fn 呼ばれない）。
 * $derived 風だが、bridge layer 経由で multi-component 間 share 可能。
 */
export function svelteComputed<T, U>(
  source: ReadonlySignal<T>,
  fn: (v: T) => U,
): { readonly value: U } {
  const derived = coreComputed(() => fn(source.value))
  let v = $state(derived.peek())
  $effect(() => effect(() => { v = derived.value }))
  return { get value() { return v } }
}

/**
 * source signal の特定 key だけ抽出する selector view。
 * `svelteComputed(source, v => v[key])` の薄い shortcut。
 */
export function svelteSelector<T, K extends keyof T>(
  source: ReadonlySignal<T>,
  key: K,
): { readonly value: T[K] } {
  return svelteComputed(source, (v) => v[key])
}
