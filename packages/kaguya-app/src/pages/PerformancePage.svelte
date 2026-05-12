<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of PerformancePage.tsx — dev/debug-only metrics view.
  All labels are English literals in the original (no i18n routing);
  faithful port preserves that. Not yet mounted at runtime —
  PerformancePage.tsx remains the live page until M5 mount swap.
-->

<script lang="ts">
  import * as PerfMonitor from '../infra/perfMonitor'
  import { emojiCount, loadState } from '../domain/emoji/emojiStore'
  import type { LoadState } from '../domain/emoji/emojiTypes'
  import { svelteSignal } from '../ui/svelteSignal.svelte'

  const apiCallsR = svelteSignal(PerfMonitor.apiCalls)
  const renderMetricsR = svelteSignal(PerfMonitor.renderMetrics)
  const totalApiCallsR = svelteSignal(PerfMonitor.totalApiCalls)
  const totalRendersR = svelteSignal(PerfMonitor.totalRenders)
  const avgApiDurationR = svelteSignal(PerfMonitor.avgApiDuration)
  const avgRenderDurationR = svelteSignal(PerfMonitor.avgRenderDuration)
  const apiSuccessRateR = svelteSignal(PerfMonitor.apiSuccessRate)
  const emojiCountR = svelteSignal(emojiCount)
  const emojiLoadStateR = svelteSignal(loadState)

  let memoryInfo = $state(PerfMonitor.getMemoryUsage())

  $effect(() => {
    const id = setInterval(() => { memoryInfo = PerfMonitor.getMemoryUsage() }, 1000)
    return () => clearInterval(id)
  })

  function formatDuration(ms: number): string { return ms.toFixed(2) + 'ms' }
  function formatBytes(bytes: number): string { return (bytes / 1024 / 1024).toFixed(2) + ' MB' }
  function formatPercent(pct: number): string { return pct.toFixed(1) + '%' }

  function emojiLoadStateLabel(s: LoadState): string {
    if (s === 'NotLoaded') return 'Not Loaded'
    if (s === 'Loading') return 'Loading...'
    if (s === 'Loaded') return 'Loaded'
    return `Error: ${s.message}`
  }

  const componentStats = $derived.by(() => {
    const map: Record<string, [number, number]> = {}
    for (const m of renderMetricsR.value) {
      const [c, d] = map[m.component] ?? [0, 0]
      map[m.component] = [c + 1, d + m.duration]
    }
    return Object.entries(map)
      .map(([comp, [count, total]]) => ({ comp, count, total, avg: total / count }))
      .sort((a, b) => b.count - a.count)
  })

  const endpointStats = $derived.by(() => {
    const map: Record<string, [number, number, number]> = {}
    for (const c of apiCallsR.value) {
      const [cnt, dur, suc] = map[c.endpoint] ?? [0, 0, 0]
      map[c.endpoint] = [cnt + 1, dur + c.duration, suc + (c.success ? 1 : 0)]
    }
    return Object.entries(map)
      .map(([ep, [count, total, success]]) => ({ ep, count, total, avg: total / count, rate: (success / count) * 100 }))
      .sort((a, b) => b.total - a.total)
  })

  function logSnapshot() {
    console.log('=== Performance Snapshot ===')
    console.log('Total API Calls:', totalApiCallsR.value)
    console.log('Avg API Duration:', avgApiDurationR.value)
    console.log('API Success Rate:', apiSuccessRateR.value)
    console.log('Total Renders:', totalRendersR.value)
    console.log('Avg Render Duration:', avgRenderDurationR.value)
    console.log('Cached Emojis:', emojiCountR.value)
    console.log('Memory:', memoryInfo)
  }
</script>

<div class="container">
  <h1>Performance Monitor</h1>

  <div class="perf-section">
    <h2>API Metrics</h2>
    <div class="stats-grid">
      <div class="stat-card"><div class="stat-label">Total API Calls</div><div class="stat-value">{totalApiCallsR.value}</div></div>
      <div class="stat-card"><div class="stat-label">Average Duration</div><div class="stat-value">{formatDuration(avgApiDurationR.value)}</div></div>
      <div class="stat-card"><div class="stat-label">Success Rate</div><div class="stat-value">{formatPercent(apiSuccessRateR.value)}</div></div>
      <div class="stat-card"><div class="stat-label">Recent Calls</div><div class="stat-value">{apiCallsR.value.length}</div></div>
    </div>
    {#if apiCallsR.value.length > 0}
      <details class="perf-details" open>
        <summary>Endpoint Breakdown</summary>
        <table class="perf-table">
          <thead><tr><th>Endpoint</th><th>Calls</th><th>Total Time</th><th>Avg Time</th><th>Success %</th></tr></thead>
          <tbody>
            {#each endpointStats as s (s.ep)}
              <tr>
                <td>{s.ep}</td><td>{s.count}</td>
                <td>{formatDuration(s.total)}</td><td>{formatDuration(s.avg)}</td>
                <td>{formatPercent(s.rate)}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </details>
      <details class="perf-details">
        <summary>Recent API Calls (last 100)</summary>
        <table class="perf-table">
          <thead><tr><th>Endpoint</th><th>Duration</th><th>Status</th></tr></thead>
          <tbody>
            {#each [...apiCallsR.value].reverse() as c, i (`${c.timestamp}-${i}`)}
              <tr>
                <td>{c.endpoint}</td><td>{formatDuration(c.duration)}</td>
                <td class={c.success ? 'success' : 'error'}>{c.success ? '✓' : '✗'}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </details>
    {:else}
      <p class="no-data">No API calls tracked yet</p>
    {/if}
  </div>

  <div class="perf-section">
    <h2>Render Metrics</h2>
    <div class="stats-grid">
      <div class="stat-card"><div class="stat-label">Total Renders</div><div class="stat-value">{totalRendersR.value}</div></div>
      <div class="stat-card"><div class="stat-label">Average Duration</div><div class="stat-value">{formatDuration(avgRenderDurationR.value)}</div></div>
      <div class="stat-card"><div class="stat-label">Recent Renders</div><div class="stat-value">{renderMetricsR.value.length}</div></div>
    </div>
    {#if renderMetricsR.value.length > 0}
      <details class="perf-details" open>
        <summary>Component Breakdown</summary>
        <table class="perf-table">
          <thead><tr><th>Component</th><th>Renders</th><th>Total Time</th><th>Avg Time</th></tr></thead>
          <tbody>
            {#each componentStats as s (s.comp)}
              <tr>
                <td>{s.comp}</td><td>{s.count}</td>
                <td>{formatDuration(s.total)}</td><td>{formatDuration(s.avg)}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </details>
      <details class="perf-details">
        <summary>Recent Renders (last 100)</summary>
        <table class="perf-table">
          <thead><tr><th>Component</th><th>Duration</th></tr></thead>
          <tbody>
            {#each [...renderMetricsR.value].reverse() as m, i (`${m.timestamp}-${i}`)}
              <tr>
                <td>{m.component}</td><td>{formatDuration(m.duration)}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </details>
    {:else}
      <p class="no-data">No renders tracked yet</p>
    {/if}
  </div>

  <div class="perf-section">
    <h2>Memory Usage</h2>
    {#if memoryInfo}
      <div class="stats-grid">
        <div class="stat-card"><div class="stat-label">Used Heap</div><div class="stat-value">{formatBytes(memoryInfo.usedJSHeapSize)}</div></div>
        <div class="stat-card"><div class="stat-label">Total Heap</div><div class="stat-value">{formatBytes(memoryInfo.totalJSHeapSize)}</div></div>
        <div class="stat-card"><div class="stat-label">Heap Limit</div><div class="stat-value">{formatBytes(memoryInfo.jsHeapSizeLimit)}</div></div>
        <div class="stat-card"><div class="stat-label">Usage %</div><div class="stat-value">{formatPercent(memoryInfo.usedJSHeapSize / memoryInfo.jsHeapSizeLimit * 100)}</div></div>
      </div>
    {:else}
      <p class="no-data">Memory info not available (Chrome only)</p>
    {/if}
  </div>

  <div class="perf-section">
    <h2>App Metrics</h2>
    <div class="stats-grid">
      <div class="stat-card"><div class="stat-label">Cached Emojis</div><div class="stat-value">{emojiCountR.value}</div></div>
      <div class="stat-card"><div class="stat-label">Emoji Load State</div><div class="stat-value">{emojiLoadStateLabel(emojiLoadStateR.value)}</div></div>
    </div>
  </div>

  <div class="perf-actions">
    <button class="secondary" type="button" onclick={() => PerfMonitor.reset()}>Reset Metrics</button>
    <button class="secondary" type="button" onclick={logSnapshot}>Log to Console</button>
  </div>
</div>
