// SPDX-License-Identifier: MPL-2.0

import { signal } from '@preact/signals-core'

export type ToastType = 'error' | 'warning' | 'info' | 'success'

export type ToastAction = {
  label: string
  onClick: () => void
}

export type Toast = {
  id: string
  message: string
  type_: ToastType
  timestamp: number
  action: ToastAction | undefined
}

export const toasts = signal<Toast[]>([])

const autoDismissTimeout = 5000

function generateId(): string {
  return `${Date.now()}-${Math.random()}`
}

export function dismissToast(id: string): void {
  toasts.value = toasts.value.filter(t => t.id !== id)
}

export function addToast(opts: { message: string; type_: ToastType; action?: ToastAction }): void {
  const newToast: Toast = {
    id: generateId(),
    message: opts.message,
    type_: opts.type_,
    timestamp: Date.now(),
    action: opts.action,
  }
  toasts.value = [...toasts.value, newToast]
  const timeout = opts.action ? 30000 : autoDismissTimeout
  setTimeout(() => dismissToast(newToast.id), timeout)
}

export function clearAll(): void {
  toasts.value = []
}

export const showError = (message: string): void => addToast({ message, type_: 'error' })
export const showWarning = (message: string): void => addToast({ message, type_: 'warning' })
export const showInfo = (message: string): void => addToast({ message, type_: 'info' })
export const showSuccess = (message: string): void => addToast({ message, type_: 'success' })

export function showInfoWithAction(message: string, action: ToastAction): void {
  addToast({ message, type_: 'info', action })
}
