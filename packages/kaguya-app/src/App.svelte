<!--
  SPDX-License-Identifier: MPL-2.0

  M1 skeleton: Svelte pipeline placeholder. Not yet mounted at runtime —
  Preact (KaguyaApp.tsx + main.tsx) remains the live root during migration.
-->

<script lang="ts">
  import { svelteSignal } from './ui/svelteSignal.svelte'
  import { currentLocale } from './infra/i18n'

  const localeView = svelteSignal(currentLocale)
</script>

<main class="svelte-skeleton">
  <h1>Kaguya (Svelte M1 skeleton)</h1>
  <p>locale: {localeView.value}</p>
</main>
