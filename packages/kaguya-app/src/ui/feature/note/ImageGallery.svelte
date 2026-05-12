<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of ImageGallery.tsx. Renders up to maxVisibleImages tiles
  in grid layout (single/double/triple/multiple class), with a
  show-more button that expands the rest. Not yet mounted at runtime.

  Hard-coded "Show more (N file(s))" string carried over verbatim from
  the Preact original — same i18n gap. coto's PR-b audit retains it.
-->

<script lang="ts">
  import type { FileView } from '../../../domain/file/fileView'
  import { isImage } from '../../../domain/file/fileView'
  import ImageAttachment from './ImageAttachment.svelte'
  import { currentLocale, t } from '../../../infra/i18n'
  import { svelteSignal } from '../../svelteSignal.svelte'

  const maxVisibleImages = 2

  type Props = { files: FileView[] }
  let { files }: Props = $props()

  const localeR = svelteSignal(currentLocale)

  let expanded = $state(false)

  const imageFiles = $derived(files.filter(isImage))
  const totalCount = $derived(imageFiles.length)
  const visibleFiles = $derived(
    expanded || totalCount <= maxVisibleImages ? imageFiles : imageFiles.slice(0, maxVisibleImages),
  )
  const hiddenCount = $derived(totalCount - visibleFiles.length)

  const gridClass = $derived(
    visibleFiles.length === 1 ? 'image-gallery single'
      : visibleFiles.length === 2 ? 'image-gallery double'
        : visibleFiles.length === 3 ? 'image-gallery triple'
          : 'image-gallery multiple',
  )

  const galleryLabel = $derived(
    (localeR.value,
      totalCount === 1 ? t('image.gallery_single') : `${totalCount}${t('image.gallery_count')}`),
  )
</script>

{#if totalCount > 0}
  <div role="group" aria-label={galleryLabel}>
    <div class={gridClass}>
      {#each visibleFiles as file, idx (file.id + idx)}
        <ImageAttachment {file} />
      {/each}
    </div>
    {#if hiddenCount > 0}
      <button
        class="show-more-files"
        type="button"
        onclick={(e) => { e.stopPropagation(); expanded = true }}
      >
        Show more ({hiddenCount} file(s))
      </button>
    {/if}
  </div>
{/if}
