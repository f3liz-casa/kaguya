// SPDX-License-Identifier: MPL-2.0
// PerfMonitor.res - Performance monitoring utilities

// ============================================================
// Types
// ============================================================

type apiCall = {
  endpoint: string,
  duration: float,
  timestamp: float,
  success: bool,
}

type renderMetric = {
  component: string,
  duration: float,
  timestamp: float,
}

// ============================================================
// Global Signals
// ============================================================

// API call history (keep last 100)
let apiCalls: PreactSignals.signal<array<apiCall>> = PreactSignals.make([])

// Render metrics (keep last 100)
let renderMetrics: PreactSignals.signal<array<renderMetric>> = PreactSignals.make([])

// Total counts
let totalApiCalls: PreactSignals.signal<int> = PreactSignals.make(0)
let totalRenders: PreactSignals.signal<int> = PreactSignals.make(0)

// ============================================================
// Helpers
// ============================================================

// Track an API call
let trackApiCall = (~endpoint: string, ~duration: float, ~success: bool): unit => {
  let call = {
    endpoint,
    duration,
    timestamp: Date.now(),
    success,
  }
  
  let current = PreactSignals.value(apiCalls)
  let updated = Array.concat(current, [call])
  
  // Keep only last 100
  let trimmed = if Array.length(updated) > 100 {
    updated->Array.sliceToEnd(~start=Array.length(updated) - 100)
  } else {
    updated
  }
  
  PreactSignals.setValue(apiCalls, trimmed)
  PreactSignals.setValue(totalApiCalls, PreactSignals.value(totalApiCalls) + 1)
}

// Track a render
let trackRender = (~component: string, ~duration: float): unit => {
  let metric = {
    component,
    duration,
    timestamp: Date.now(),
  }
  
  let current = PreactSignals.value(renderMetrics)
  let updated = Array.concat(current, [metric])
  
  // Keep only last 100
  let trimmed = if Array.length(updated) > 100 {
    updated->Array.sliceToEnd(~start=Array.length(updated) - 100)
  } else {
    updated
  }
  
  PreactSignals.setValue(renderMetrics, trimmed)
  PreactSignals.setValue(totalRenders, PreactSignals.value(totalRenders) + 1)
}

// Measure API call performance
let measureApiCall = async (
  ~endpoint: string,
  ~fn: unit => promise<'a>,
): 'a => {
  let start = Date.now()
  
  try {
    let result = await fn()
    let duration = Date.now() -. start
    trackApiCall(~endpoint, ~duration, ~success=true)
    result
  } catch {
  | error => {
      let duration = Date.now() -. start
      trackApiCall(~endpoint, ~duration, ~success=false)
      raise(error)
    }
  }
}

// Hook to track component render time
// Usage: let _ = useRenderMetrics("ComponentName")
let useRenderMetrics = (~component: string): unit => {
  let renderStartRef = PreactHooks.useRef(Date.now())
  
  // Track render completion (runs after render)
  PreactHooks.useEffect0(() => {
    let duration = Date.now() -. renderStartRef.current
    trackRender(~component, ~duration)
    
    // Update ref for next render
    renderStartRef.current = Date.now()
    
    None
  })
}

// ============================================================
// Computed Metrics
// ============================================================

let avgApiDuration: PreactSignals.computed<float> = PreactSignals.computed(() => {
  let calls = PreactSignals.value(apiCalls)
  if Array.length(calls) == 0 {
    0.0
  } else {
    let total = calls->Array.reduce(0.0, (acc, call) => acc +. call.duration)
    total /. Int.toFloat(Array.length(calls))
  }
})

let avgRenderDuration: PreactSignals.computed<float> = PreactSignals.computed(() => {
  let metrics = PreactSignals.value(renderMetrics)
  if Array.length(metrics) == 0 {
    0.0
  } else {
    let total = metrics->Array.reduce(0.0, (acc, metric) => acc +. metric.duration)
    total /. Int.toFloat(Array.length(metrics))
  }
})

let apiSuccessRate: PreactSignals.computed<float> = PreactSignals.computed(() => {
  let calls = PreactSignals.value(apiCalls)
  if Array.length(calls) == 0 {
    100.0
  } else {
    let successful = calls->Array.filter(call => call.success)->Array.length
    Int.toFloat(successful) /. Int.toFloat(Array.length(calls)) *. 100.0
  }
})

// ============================================================
// Memory API Bindings
// ============================================================

type memoryInfo = {
  usedJSHeapSize: float,
  totalJSHeapSize: float,
  jsHeapSizeLimit: float,
}

// Performance.memory is only available in Chrome and is undefined in other browsers
@val @scope("performance") @return(nullable)
external memoryInfoUnsafe: option<memoryInfo> = "memory"

let getMemoryUsage = (): option<memoryInfo> => {
  memoryInfoUnsafe
}

// ============================================================
// Reset
// ============================================================

let reset = (): unit => {
  PreactSignals.batch(() => {
    PreactSignals.setValue(apiCalls, [])
    PreactSignals.setValue(renderMetrics, [])
    PreactSignals.setValue(totalApiCalls, 0)
    PreactSignals.setValue(totalRenders, 0)
  })
}
