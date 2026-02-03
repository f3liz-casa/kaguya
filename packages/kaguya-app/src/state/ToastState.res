// SPDX-License-Identifier: MPL-2.0
// ToastState.res - Global toast notification state

// ============================================================
// Types
// ============================================================

type toastType = [#error | #warning | #info | #success]

type toast = {
  id: string,
  message: string,
  type_: toastType,
  timestamp: float,
}

// ============================================================
// Global State
// ============================================================

let toasts: PreactSignals.signal<array<toast>> = PreactSignals.make([])

// Auto-dismiss timeout in milliseconds
let autoDismissTimeout = 5000.0

// ============================================================
// Actions
// ============================================================

// Generate unique ID for toast
let generateId = (): string => {
  let timestamp = Date.now()
  let random = Math.random()
  Float.toString(timestamp) ++ "-" ++ Float.toString(random)
}

// Dismiss a specific toast by ID
let dismissToast = (id: string): unit => {
  PreactSignals.setValue(toasts, 
    PreactSignals.value(toasts)->Array.filter(toast => toast.id != id)
  )
}

// Add a toast notification
let addToast = (~message: string, ~type_: toastType): unit => {
  let newToast = {
    id: generateId(),
    message,
    type_,
    timestamp: Date.now(),
  }
  
  PreactSignals.setValue(toasts, Array.concat(PreactSignals.value(toasts), [newToast]))
  
  // Auto-dismiss after timeout
  let _ = SetTimeout.make(() => {
    dismissToast(newToast.id)
  }, Float.toInt(autoDismissTimeout))
}

// Clear all toasts
let clearAll = (): unit => {
  PreactSignals.setValue(toasts, [])
}

// ============================================================
// Convenience Functions
// ============================================================

let showError = (message: string): unit => {
  addToast(~message, ~type_=#error)
}

let showWarning = (message: string): unit => {
  addToast(~message, ~type_=#warning)
}

let showInfo = (message: string): unit => {
  addToast(~message, ~type_=#info)
}

let showSuccess = (message: string): unit => {
  addToast(~message, ~type_=#success)
}
