// SPDX-License-Identifier: MPL-2.0

import { useState, useEffect } from 'preact/hooks'
import * as PerfMonitor from '../infra/perfMonitor'
import { emojiCount, loadState } from '../domain/emoji/emojiStore'
import type { LoadState } from '../domain/emoji/emojiTypes'

function formatDuration(ms: number): string { return ms.toFixed(2) + 'ms' }
function formatBytes(bytes: number): string { return (bytes / 1024 / 1024).toFixed(2) + ' MB' }
function formatPercent(pct: number): string { return pct.toFixed(1) + '%' }

function emojiLoadStateLabel(s: LoadState): string {
  if (s === 'NotLoaded') return 'Not Loaded'
  if (s === 'Loading') return 'Loading...'
  if (s === 'Loaded') return 'Loaded'
  return `Error: ${s.message}`
}

export function PerformancePage() {
  const apiCallsVal = PerfMonitor.apiCalls.value
  const renderMetricsVal = PerfMonitor.renderMetrics.value
  const totalApiCallsVal = PerfMonitor.totalApiCalls.value
  const totalRendersVal = PerfMonitor.totalRenders.value
  const avgApiDurationVal = PerfMonitor.avgApiDuration.value
  const avgRenderDurationVal = PerfMonitor.avgRenderDuration.value
  const apiSuccessRateVal = PerfMonitor.apiSuccessRate.value
  const [memoryInfo, setMemoryInfo] = useState(() => PerfMonitor.getMemoryUsage())
  const emojiCountVal = emojiCount.value
  const emojiLoadStateVal = loadState.value

  useEffect(() => {
    const interval = setInterval(() => setMemoryInfo(PerfMonitor.getMemoryUsage()), 1000)
    return () => clearInterval(interval)
  }, [])

  // Aggregate by component
  const componentStatsMap: Record<string, [number, number]> = {}
  for (const m of renderMetricsVal) {
    const [c, d] = componentStatsMap[m.component] ?? [0, 0]
    componentStatsMap[m.component] = [c + 1, d + m.duration]
  }
  const componentStats = Object.entries(componentStatsMap)
    .map(([comp, [count, total]]) => ({ comp, count, total, avg: total / count }))
    .sort((a, b) => b.count - a.count)

  // Aggregate by endpoint
  const endpointStatsMap: Record<string, [number, number, number]> = {}
  for (const c of apiCallsVal) {
    const [cnt, dur, suc] = endpointStatsMap[c.endpoint] ?? [0, 0, 0]
    endpointStatsMap[c.endpoint] = [cnt + 1, dur + c.duration, suc + (c.success ? 1 : 0)]
  }
  const endpointStats = Object.entries(endpointStatsMap)
    .map(([ep, [count, total, success]]) => ({ ep, count, total, avg: total / count, rate: (success / count) * 100 }))
    .sort((a, b) => b.total - a.total)

  return (
    <div class="container">
      <h1>Performance Monitor</h1>

      <div class="perf-section">
        <h2>API Metrics</h2>
        <div class="stats-grid">
          <div class="stat-card"><div class="stat-label">Total API Calls</div><div class="stat-value">{totalApiCallsVal}</div></div>
          <div class="stat-card"><div class="stat-label">Average Duration</div><div class="stat-value">{formatDuration(avgApiDurationVal)}</div></div>
          <div class="stat-card"><div class="stat-label">Success Rate</div><div class="stat-value">{formatPercent(apiSuccessRateVal)}</div></div>
          <div class="stat-card"><div class="stat-label">Recent Calls</div><div class="stat-value">{apiCallsVal.length}</div></div>
        </div>
        {apiCallsVal.length > 0 && (
          <>
            <details class="perf-details" open>
              <summary>Endpoint Breakdown</summary>
              <table class="perf-table">
                <thead><tr><th>Endpoint</th><th>Calls</th><th>Total Time</th><th>Avg Time</th><th>Success %</th></tr></thead>
                <tbody>
                  {endpointStats.map(s => (
                    <tr key={s.ep}>
                      <td>{s.ep}</td><td>{s.count}</td>
                      <td>{formatDuration(s.total)}</td><td>{formatDuration(s.avg)}</td>
                      <td>{formatPercent(s.rate)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </details>
            <details class="perf-details">
              <summary>Recent API Calls (last 100)</summary>
              <table class="perf-table">
                <thead><tr><th>Endpoint</th><th>Duration</th><th>Status</th></tr></thead>
                <tbody>
                  {[...apiCallsVal].reverse().map((c, i) => (
                    <tr key={`${c.timestamp}-${i}`}>
                      <td>{c.endpoint}</td><td>{formatDuration(c.duration)}</td>
                      <td class={c.success ? 'success' : 'error'}>{c.success ? '✓' : '✗'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </details>
          </>
        )}
        {!apiCallsVal.length && <p class="no-data">No API calls tracked yet</p>}
      </div>

      <div class="perf-section">
        <h2>Render Metrics</h2>
        <div class="stats-grid">
          <div class="stat-card"><div class="stat-label">Total Renders</div><div class="stat-value">{totalRendersVal}</div></div>
          <div class="stat-card"><div class="stat-label">Average Duration</div><div class="stat-value">{formatDuration(avgRenderDurationVal)}</div></div>
          <div class="stat-card"><div class="stat-label">Recent Renders</div><div class="stat-value">{renderMetricsVal.length}</div></div>
        </div>
        {renderMetricsVal.length > 0 && (
          <>
            <details class="perf-details" open>
              <summary>Component Breakdown</summary>
              <table class="perf-table">
                <thead><tr><th>Component</th><th>Renders</th><th>Total Time</th><th>Avg Time</th></tr></thead>
                <tbody>
                  {componentStats.map(s => (
                    <tr key={s.comp}>
                      <td>{s.comp}</td><td>{s.count}</td>
                      <td>{formatDuration(s.total)}</td><td>{formatDuration(s.avg)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </details>
            <details class="perf-details">
              <summary>Recent Renders (last 100)</summary>
              <table class="perf-table">
                <thead><tr><th>Component</th><th>Duration</th></tr></thead>
                <tbody>
                  {[...renderMetricsVal].reverse().map((m, i) => (
                    <tr key={`${m.timestamp}-${i}`}>
                      <td>{m.component}</td><td>{formatDuration(m.duration)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </details>
          </>
        )}
        {!renderMetricsVal.length && <p class="no-data">No renders tracked yet</p>}
      </div>

      <div class="perf-section">
        <h2>Memory Usage</h2>
        {memoryInfo ? (
          <div class="stats-grid">
            <div class="stat-card"><div class="stat-label">Used Heap</div><div class="stat-value">{formatBytes(memoryInfo.usedJSHeapSize)}</div></div>
            <div class="stat-card"><div class="stat-label">Total Heap</div><div class="stat-value">{formatBytes(memoryInfo.totalJSHeapSize)}</div></div>
            <div class="stat-card"><div class="stat-label">Heap Limit</div><div class="stat-value">{formatBytes(memoryInfo.jsHeapSizeLimit)}</div></div>
            <div class="stat-card"><div class="stat-label">Usage %</div><div class="stat-value">{formatPercent(memoryInfo.usedJSHeapSize / memoryInfo.jsHeapSizeLimit * 100)}</div></div>
          </div>
        ) : (
          <p class="no-data">Memory info not available (Chrome only)</p>
        )}
      </div>

      <div class="perf-section">
        <h2>App Metrics</h2>
        <div class="stats-grid">
          <div class="stat-card"><div class="stat-label">Cached Emojis</div><div class="stat-value">{emojiCountVal}</div></div>
          <div class="stat-card"><div class="stat-label">Emoji Load State</div><div class="stat-value">{emojiLoadStateLabel(emojiLoadStateVal)}</div></div>
        </div>
      </div>

      <div class="perf-actions">
        <button class="secondary" onClick={() => PerfMonitor.reset()} type="button">Reset Metrics</button>
        <button class="secondary" type="button" onClick={() => {
          console.log('=== Performance Snapshot ===')
          console.log('Total API Calls:', totalApiCallsVal)
          console.log('Avg API Duration:', avgApiDurationVal)
          console.log('API Success Rate:', apiSuccessRateVal)
          console.log('Total Renders:', totalRendersVal)
          console.log('Avg Render Duration:', avgRenderDurationVal)
          console.log('Cached Emojis:', emojiCountVal)
          console.log('Memory:', memoryInfo)
        }}>Log to Console</button>
      </div>
    </div>
  )
}
