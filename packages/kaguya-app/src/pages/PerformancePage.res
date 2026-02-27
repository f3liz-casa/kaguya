// SPDX-License-Identifier: MPL-2.0

@jsx.component
let make = () => {
  // Performance metrics - directly access signal values (auto-subscribes in components)
  let apiCalls = PreactSignals.value(PerfMonitor.apiCalls)
  let renderMetrics = PreactSignals.value(PerfMonitor.renderMetrics)
  let totalApiCalls = PreactSignals.value(PerfMonitor.totalApiCalls)
  let totalRenders = PreactSignals.value(PerfMonitor.totalRenders)
  let avgApiDuration = PreactSignals.value(PerfMonitor.avgApiDuration)
  let avgRenderDuration = PreactSignals.value(PerfMonitor.avgRenderDuration)
  let apiSuccessRate = PreactSignals.value(PerfMonitor.apiSuccessRate)

  // Memory info (update every second)
  let (memoryInfo, setMemoryInfo) = PreactHooks.useState(() => PerfMonitor.getMemoryUsage())

  PreactHooks.useEffect0(() => {
    let interval = setInterval(() => {
      setMemoryInfo(_ => PerfMonitor.getMemoryUsage())
    }, 1000)

    Some(() => clearInterval(interval))
  })

  // App-specific metrics
  let emojiCount = PreactSignals.value(EmojiStore.emojiCount)
  let emojiLoadState = PreactSignals.value(EmojiStore.loadState)

  let formatDuration = (ms: float): string => {
    Float.toFixed(ms, ~digits=2) ++ "ms"
  }

  let formatBytes = (bytes: float): string => {
    let mb = bytes /. 1024.0 /. 1024.0
    Float.toFixed(mb, ~digits=2) ++ " MB"
  }

  let formatPercent = (pct: float): string => {
    Float.toFixed(pct, ~digits=1) ++ "%"
  }

  // Aggregate render metrics by component
  let componentStats = {
    let statsMap = Dict.make()

    renderMetrics->Array.forEach(metric => {
      let component = metric.component

      switch statsMap->Dict.get(component) {
      | Some((count, totalDuration)) =>
        statsMap->Dict.set(component, (count + 1, totalDuration +. metric.duration))
      | None => statsMap->Dict.set(component, (1, metric.duration))
      }
    })

    statsMap
    ->Dict.toArray
    ->Array.map(((component, (count, totalDuration))) => {
      (component, count, totalDuration, totalDuration /. Int.toFloat(count))
    })
    ->Array.toSorted((a, b) => {
      let (_, countA, _, _) = a
      let (_, countB, _, _) = b
      Float.fromInt(countB - countA)
    })
  }

  // Aggregate API calls by endpoint
  let endpointStats = {
    let statsMap = Dict.make()

    apiCalls->Array.forEach(call => {
      let endpoint = call.endpoint

      switch statsMap->Dict.get(endpoint) {
      | Some((count, totalDuration, successCount)) =>
        statsMap->Dict.set(
          endpoint,
          (count + 1, totalDuration +. call.duration, successCount + (call.success ? 1 : 0)),
        )
      | None => statsMap->Dict.set(endpoint, (1, call.duration, call.success ? 1 : 0))
      }
    })

    statsMap
    ->Dict.toArray
    ->Array.map(((endpoint, (count, totalDuration, successCount))) => {
      (
        endpoint,
        count,
        totalDuration,
        totalDuration /. Int.toFloat(count),
        Int.toFloat(successCount) /. Int.toFloat(count) *. 100.0,
      )
    })
    ->Array.toSorted((a, b) => {
      let (_, _, totalA, _, _) = a
      let (_, _, totalB, _, _) = b

      // Sort by total duration descending (slowest endpoints first)
      if totalB > totalA {
        1.0
      } else if totalB < totalA {
        -1.0
      } else {
        0.0
      }
    })
  }

  <div className="container">
    <h1> {Preact.string("Performance Monitor")} </h1>

    <div className="perf-section">
      <h2> {Preact.string("API Metrics")} </h2>
      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-label"> {Preact.string("Total API Calls")} </div>
          <div className="stat-value"> {Preact.string(Int.toString(totalApiCalls))} </div>
        </div>

        <div className="stat-card">
          <div className="stat-label"> {Preact.string("Average Duration")} </div>
          <div className="stat-value"> {Preact.string(formatDuration(avgApiDuration))} </div>
        </div>

        <div className="stat-card">
          <div className="stat-label"> {Preact.string("Success Rate")} </div>
          <div className="stat-value"> {Preact.string(formatPercent(apiSuccessRate))} </div>
        </div>

        <div className="stat-card">
          <div className="stat-label"> {Preact.string("Recent Calls")} </div>
          <div className="stat-value"> {Preact.string(Int.toString(Array.length(apiCalls)))} </div>
        </div>
      </div>

      {if Array.length(apiCalls) > 0 {
        <>
          <details className="perf-details" open_={true}>
            <summary> {Preact.string("Endpoint Breakdown")} </summary>
            <table className="perf-table">
              <thead>
                <tr>
                  <th> {Preact.string("Endpoint")} </th>
                  <th> {Preact.string("Calls")} </th>
                  <th> {Preact.string("Total Time")} </th>
                  <th> {Preact.string("Avg Time")} </th>
                  <th> {Preact.string("Success %")} </th>
                </tr>
              </thead>
              <tbody>
                {endpointStats
                ->Array.map(((endpoint, count, totalDuration, avgDuration, successRate)) => {
                  <tr key={endpoint}>
                    <td> {Preact.string(endpoint)} </td>
                    <td> {Preact.string(Int.toString(count))} </td>
                    <td> {Preact.string(formatDuration(totalDuration))} </td>
                    <td> {Preact.string(formatDuration(avgDuration))} </td>
                    <td> {Preact.string(formatPercent(successRate))} </td>
                  </tr>
                })
                ->Preact.array}
              </tbody>
            </table>
          </details>

          <details className="perf-details">
            <summary> {Preact.string("Recent API Calls (last 100)")} </summary>
            <table className="perf-table">
              <thead>
                <tr>
                  <th> {Preact.string("Endpoint")} </th>
                  <th> {Preact.string("Duration")} </th>
                  <th> {Preact.string("Status")} </th>
                </tr>
              </thead>
              <tbody>
                {apiCalls
                ->Array.toReversed
                ->Array.mapWithIndex((call, index) => {
                  <tr key={Float.toString(call.timestamp) ++ "-" ++ Int.toString(index)}>
                    <td> {Preact.string(call.endpoint)} </td>
                    <td> {Preact.string(formatDuration(call.duration))} </td>
                    <td className={call.success ? "success" : "error"}>
                      {Preact.string(call.success ? "✓" : "✗")}
                    </td>
                  </tr>
                })
                ->Preact.array}
              </tbody>
            </table>
          </details>
        </>
      } else {
        <p className="no-data"> {Preact.string("No API calls tracked yet")} </p>
      }}
    </div>

    <div className="perf-section">
      <h2> {Preact.string("Render Metrics")} </h2>
      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-label"> {Preact.string("Total Renders")} </div>
          <div className="stat-value"> {Preact.string(Int.toString(totalRenders))} </div>
        </div>

        <div className="stat-card">
          <div className="stat-label"> {Preact.string("Average Duration")} </div>
          <div className="stat-value"> {Preact.string(formatDuration(avgRenderDuration))} </div>
        </div>

        <div className="stat-card">
          <div className="stat-label"> {Preact.string("Recent Renders")} </div>
          <div className="stat-value">
            {Preact.string(Int.toString(Array.length(renderMetrics)))}
          </div>
        </div>
      </div>

      {if Array.length(renderMetrics) > 0 {
        <>
          <details className="perf-details" open_={true}>
            <summary> {Preact.string("Component Breakdown")} </summary>
            <table className="perf-table">
              <thead>
                <tr>
                  <th> {Preact.string("Component")} </th>
                  <th> {Preact.string("Renders")} </th>
                  <th> {Preact.string("Total Time")} </th>
                  <th> {Preact.string("Avg Time")} </th>
                </tr>
              </thead>
              <tbody>
                {componentStats
                ->Array.map(((component, count, totalDuration, avgDuration)) => {
                  <tr key={component}>
                    <td> {Preact.string(component)} </td>
                    <td> {Preact.string(Int.toString(count))} </td>
                    <td> {Preact.string(formatDuration(totalDuration))} </td>
                    <td> {Preact.string(formatDuration(avgDuration))} </td>
                  </tr>
                })
                ->Preact.array}
              </tbody>
            </table>
          </details>

          <details className="perf-details">
            <summary> {Preact.string("Recent Renders (last 100)")} </summary>
            <table className="perf-table">
              <thead>
                <tr>
                  <th> {Preact.string("Component")} </th>
                  <th> {Preact.string("Duration")} </th>
                </tr>
              </thead>
              <tbody>
                {renderMetrics
                ->Array.toReversed
                ->Array.mapWithIndex((metric, index) => {
                  <tr key={Float.toString(metric.timestamp) ++ "-" ++ Int.toString(index)}>
                    <td> {Preact.string(metric.component)} </td>
                    <td> {Preact.string(formatDuration(metric.duration))} </td>
                  </tr>
                })
                ->Preact.array}
              </tbody>
            </table>
          </details>
        </>
      } else {
        <p className="no-data"> {Preact.string("No renders tracked yet")} </p>
      }}
    </div>

    <div className="perf-section">
      <h2> {Preact.string("Memory Usage")} </h2>
      {switch memoryInfo {
      | Some(info) =>
        <div className="stats-grid">
          <div className="stat-card">
            <div className="stat-label"> {Preact.string("Used Heap")} </div>
            <div className="stat-value"> {Preact.string(formatBytes(info.usedJSHeapSize))} </div>
          </div>

          <div className="stat-card">
            <div className="stat-label"> {Preact.string("Total Heap")} </div>
            <div className="stat-value"> {Preact.string(formatBytes(info.totalJSHeapSize))} </div>
          </div>

          <div className="stat-card">
            <div className="stat-label"> {Preact.string("Heap Limit")} </div>
            <div className="stat-value"> {Preact.string(formatBytes(info.jsHeapSizeLimit))} </div>
          </div>

          <div className="stat-card">
            <div className="stat-label"> {Preact.string("Usage %")} </div>
            <div className="stat-value">
              {Preact.string(formatPercent(info.usedJSHeapSize /. info.jsHeapSizeLimit *. 100.0))}
            </div>
          </div>
        </div>
      | None =>
        <p className="no-data"> {Preact.string("Memory info not available (Chrome only)")} </p>
      }}
    </div>

    <div className="perf-section">
      <h2> {Preact.string("App Metrics")} </h2>
      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-label"> {Preact.string("Cached Emojis")} </div>
          <div className="stat-value"> {Preact.string(Int.toString(emojiCount))} </div>
        </div>

        <div className="stat-card">
          <div className="stat-label"> {Preact.string("Emoji Load State")} </div>
          <div className="stat-value">
            {Preact.string(
              switch emojiLoadState {
              | EmojiTypes.NotLoaded => "Not Loaded"
              | EmojiTypes.Loading => "Loading..."
              | EmojiTypes.Loaded => "Loaded"
              | EmojiTypes.LoadError(msg) => "Error: " ++ msg
              },
            )}
          </div>
        </div>
      </div>
    </div>

    <div className="perf-actions">
      <button
        className="secondary"
        onClick={_ => {
          PerfMonitor.reset()
        }}
      >
        {Preact.string("Reset Metrics")}
      </button>

      <button
        className="secondary"
        onClick={_ => {
          Console.log("=== Performance Snapshot ===")
          Console.log2("Total API Calls:", totalApiCalls)
          Console.log2("Avg API Duration:", avgApiDuration)
          Console.log2("API Success Rate:", apiSuccessRate)
          Console.log2("Total Renders:", totalRenders)
          Console.log2("Avg Render Duration:", avgRenderDuration)
          Console.log2("Cached Emojis:", emojiCount)
          Console.log2("Memory:", memoryInfo)
        }}
      >
        {Preact.string("Log to Console")}
      </button>
    </div>
  </div>
}
