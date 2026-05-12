<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of PushManualRegistrationPage.tsx. Native Misskey push
  is handled by PushNotificationToggle now; this page is a stub kept
  for backward-compatible deep links.

  Not yet mounted at runtime — the Preact .tsx page remains live
  until M5 mount swap.
-->

<script lang="ts">
  import Layout from '../ui/Layout.svelte'
  import Link from '../ui/Link.svelte'
  import { currentLocale, t } from '../infra/i18n'
  import { svelteSignal } from '../ui/svelteSignal.svelte'

  const localeR = svelteSignal(currentLocale)
  const L = $derived((localeR.value, {
    migrated: t('push.migrated'),
    backToSettings: t('push.back_to_settings'),
  }))
</script>

<Layout>
  <div style="padding: 20px">
    <p>{L.migrated}</p>
    <Link href="/settings">{L.backToSettings}</Link>
  </div>
</Layout>
