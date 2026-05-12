<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of ImageLightbox.tsx. Modal-style image viewer with
  Escape-to-close and body scroll lock. Not yet mounted at runtime —
  ImageLightbox.tsx remains the live component until M5 mount swap.
-->

<script lang="ts">
  import { currentLocale, t } from '../../infra/i18n'
  import { svelteSignal } from '../../ui/svelteSignal.svelte'

  type Props = { url: string; name: string; onClose: () => void }
  let { url, name, onClose }: Props = $props()

  const localeR = svelteSignal(currentLocale)
  const L = $derived((localeR.value, {
    viewer: t('image.viewer'),
    closeViewer: t('image.close_viewer'),
  }))

  $effect(() => {
    function handleEscape(e: KeyboardEvent) {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', handleEscape)
    return () => document.removeEventListener('keydown', handleEscape)
  })

  $effect(() => {
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => { document.body.style.overflow = prev }
  })
</script>

<div
  class="lightbox-overlay"
  role="dialog"
  aria-modal="true"
  aria-label={L.viewer}
  onclick={() => onClose()}
>
  <div class="lightbox-content" role="presentation" onclick={(e) => e.stopPropagation()}>
    <button class="lightbox-close" type="button" aria-label={L.closeViewer} onclick={() => onClose()}>×</button>
    <img class="lightbox-image" src={url} alt={name} onclick={() => onClose()} role="img" />
  </div>
</div>
