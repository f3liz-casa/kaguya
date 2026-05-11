// SPDX-License-Identifier: MPL-2.0

import { toasts, dismissToast, type Toast } from './toastState'
import { t } from '../infra/i18n'

const iconMap = {
  error: '❌',
  warning: '⚠️',
  info: 'ℹ️',
  success: '✓',
}

type ToastItemProps = {
  toast: Toast
  onDismiss: () => void
}

function ToastItem({ toast, onDismiss }: ToastItemProps) {
  const icon = iconMap[toast.type_]

  return (
    <div
      className="toast-item"
      data-type={toast.type_}
      role="alert"
      aria-live="assertive"
    >
      <span className="toast-icon" aria-hidden="true">{icon}</span>
      <div className="toast-content">
        {toast.message}
        {toast.action && (
          <div>
            <button
              className="toast-action-btn"
              onClick={() => toast.action!.onClick()}
              type="button"
            >
              {toast.action.label}
            </button>
          </div>
        )}
      </div>
      <button
        className="toast-close-btn"
        onClick={onDismiss}
        aria-label={t('notifications.close')}
        type="button"
      >
        ×
      </button>
    </div>
  )
}

export function Toast() {
  const currentToasts = toasts.value
  if (currentToasts.length === 0) return null

  return (
    <div className="toast-container" aria-live="polite">
      <div className="toast-inner">
        {currentToasts.map(toast => (
          <ToastItem key={toast.id} toast={toast} onDismiss={() => dismissToast(toast.id)} />
        ))}
      </div>
    </div>
  )
}
