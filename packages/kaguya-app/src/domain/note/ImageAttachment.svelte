<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of ImageAttachment.tsx. Click-to-enlarge image tile with
  sensitive-content opt-in overlay. Not yet mounted at runtime —
  ImageAttachment.tsx remains the live component until M5 mount swap.
-->

<script lang="ts">
  import type { FileView } from '../file/fileView'
  import { isImage } from '../file/fileView'
  import ImageLightbox from './ImageLightbox.svelte'
  import { currentLocale, t } from '../../infra/i18n'
  import { proxyUrl } from '../../infra/mediaProxy'
  import { svelteSignal } from '../../ui/svelteSignal.svelte'

  type Props = { file: FileView }
  let { file }: Props = $props()

  const localeR = svelteSignal(currentLocale)

  let showSensitive = $state(!file.isSensitive)
  let showLightbox = $state(false)
  let imageLoaded = $state(false)

  const thumbnailUrl = $derived(proxyUrl(file.thumbnailUrl ?? file.url))
  const fullUrl = $derived(proxyUrl(file.url))

  const L = $derived((localeR.value, {
    sensitiveAria: t('image.sensitive_aria'),
    enlarge: t('image.enlarge'),
    showSensitive: t('image.show_sensitive'),
    sensitiveLabel: t('image.sensitive_label'),
    tapToShow: t('image.tap_to_show'),
  }))
</script>

{#if isImage(file) && file.url}
  <div
    class="image-attachment"
    role="button"
    tabindex={showSensitive ? 0 : -1}
    aria-label={file.isSensitive && !showSensitive ? L.sensitiveAria : `${L.enlarge}: ${file.name}`}
  >
    {#if file.isSensitive && !showSensitive}
      <div
        class="sensitive-overlay"
        role="button"
        tabindex="0"
        aria-label={L.showSensitive}
        onclick={() => { showSensitive = true }}
        onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') showSensitive = true }}
      >
        <div class="sensitive-warning" aria-hidden="true">
          <span class="sensitive-icon">⚠️</span>
          <span class="sensitive-text">{L.sensitiveLabel}</span>
          <small class="sensitive-hint">{L.tapToShow}</small>
        </div>
      </div>
    {/if}
    {#if !imageLoaded && thumbnailUrl !== fullUrl}
      <img
        class={file.isSensitive && !showSensitive ? 'image-sensitive-hidden' : 'image-placeholder'}
        src={thumbnailUrl}
        width={file.width?.toString()}
        height={file.height?.toString()}
        alt=""
        aria-hidden="true"
        role="presentation"
      />
    {/if}
    <img
      class={
        file.isSensitive && !showSensitive ? 'image-sensitive-hidden'
        : imageLoaded ? 'image-content image-loaded'
        : 'image-content image-loading'
      }
      src={fullUrl}
      width={file.width?.toString()}
      height={file.height?.toString()}
      alt={file.name}
      loading="lazy"
      onload={() => { imageLoaded = true }}
      onclick={(e) => { e.stopPropagation(); if (showSensitive) showLightbox = true }}
      style="cursor: {showSensitive ? 'zoom-in' : 'default'}"
      role="img"
      aria-hidden={file.isSensitive && !showSensitive}
    />
  </div>
  {#if showLightbox}
    <ImageLightbox url={fullUrl} name={file.name} onClose={() => { showLightbox = false }} />
  {/if}
{/if}
