// SPDX-License-Identifier: MPL-2.0

import { signal, computed } from '@preact/signals-core'

export type ApiCall = { endpoint: string; duration: number; timestamp: number; success: boolean }
export type RenderMetric = { component: string; duration: number; timestamp: number }

export const apiCalls = signal<ApiCall[]>([])
export const renderMetrics = signal<RenderMetric[]>([])
export const totalApiCalls = signal(0)
export const totalRenders = signal(0)

export const avgApiDuration = computed(() => {
  const calls = apiCalls.value
  if (!calls.length) return 0
  return calls.reduce((a, c) => a + c.duration, 0) / calls.length
})

export const avgRenderDuration = computed(() => {
  const metrics = renderMetrics.value
  if (!metrics.length) return 0
  return metrics.reduce((a, m) => a + m.duration, 0) / metrics.length
})

export const apiSuccessRate = computed(() => {
  const calls = apiCalls.value
  if (!calls.length) return 100
  return (calls.filter(c => c.success).length / calls.length) * 100
})

function trim<T>(arr: T[]): T[] {
  return arr.length > 100 ? arr.slice(arr.length - 100) : arr
}

export function trackApiCall(endpoint: string, duration: number, success: boolean): void {
  apiCalls.value = trim([...apiCalls.value, { endpoint, duration, timestamp: Date.now(), success }])
  totalApiCalls.value++
}

export function trackRender(component: string, duration: number): void {
  renderMetrics.value = trim([...renderMetrics.value, { component, duration, timestamp: Date.now() }])
  totalRenders.value++
}

export async function measureApiCall<T>(endpoint: string, fn: () => Promise<T>): Promise<T> {
  const start = Date.now()
  try {
    const result = await fn()
    trackApiCall(endpoint, Date.now() - start, true)
    return result
  } catch (e) {
    trackApiCall(endpoint, Date.now() - start, false)
    throw e
  }
}

export type MemoryInfo = { usedJSHeapSize: number; totalJSHeapSize: number; jsHeapSizeLimit: number }

export function getMemoryUsage(): MemoryInfo | undefined {
  return (performance as unknown as { memory?: MemoryInfo }).memory
}

export function reset(): void {
  apiCalls.value = []
  renderMetrics.value = []
  totalApiCalls.value = 0
  totalRenders.value = 0
}
