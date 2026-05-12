<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of Toast.tsx. Not yet mounted at runtime — Toast.tsx
  remains the live root component until M1 mount swap.
-->

<script lang="ts">
  import { toasts, dismissToast, type ToastType } from './toastState'
  import { currentLocale, t } from '../infra/i18n'
  import { svelteSignal } from './svelteSignal.svelte'

  const toastsR = svelteSignal(toasts)
  const localeR = svelteSignal(currentLocale)

  const iconMap: Record<ToastType, string> = {
    error: '❌',
    warning: '⚠️',
    info: 'ℹ️',
    success: '✓',
  }

  // Tie `t()` re-evaluation to locale changes (comma operator).
  const closeLabel = $derived((localeR.value, t('notifications.close')))
</script>

{#if toastsR.value.length > 0}
  <div class="toast-container" aria-live="polite">
    <div class="toast-inner">
      {#each toastsR.value as toast (toast.id)}
        <div
          class="toast-item"
          data-type={toast.type_}
          role="alert"
          aria-live="assertive"
        >
          <span class="toast-icon" aria-hidden="true">{iconMap[toast.type_]}</span>
          <div class="toast-content">
            {toast.message}
            {#if toast.action}
              <div>
                <button
                  class="toast-action-btn"
                  type="button"
                  onclick={() => toast.action!.onClick()}
                >
                  {toast.action.label}
                </button>
              </div>
            {/if}
          </div>
          <button
            class="toast-close-btn"
            type="button"
            aria-label={closeLabel}
            onclick={() => dismissToast(toast.id)}
          >
            ×
          </button>
        </div>
      {/each}
    </div>
  </div>
{/if}
