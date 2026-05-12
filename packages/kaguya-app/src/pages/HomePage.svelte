<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of HomePage.tsx. Thin wrapper around HomePageTimeline
  inside the Layout shell. Not yet mounted at runtime — HomePage.tsx
  remains the live page until M5 mount swap.
-->

<script lang="ts">
  import Layout from '../ui/Layout.svelte'
  import HomePageTimeline from '../domain/timeline/HomePageTimeline.svelte'
</script>

<Layout>
  <HomePageTimeline />
</Layout>
