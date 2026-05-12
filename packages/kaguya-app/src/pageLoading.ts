// SPDX-License-Identifier: MPL-2.0
// Global page-loading counter that drives the top progress bar.

import { signal, computed } from '@preact/signals-core'

const _count = signal(0)

export const isLoading = computed(() => _count.value > 0)

export function start(): void {
  _count.value = _count.value + 1
}

export function done_(): void {
  _count.value = Math.max(0, _count.value - 1)
}
