<!--
  SPDX-License-Identifier: MPL-2.0

  Svelte port of SettingsPage's inline FilteredTimelineSection. Owns
  the filter logic (AND/OR), the existing rules list, and the
  add-new-rule row. Not yet mounted at runtime.
-->

<script lang="ts">
  import {
    filterConfig,
    addRule,
    removeRule,
    updateRule,
    setFilterLogic,
  } from '../domain/timeline/filteredTimelineStore'
  import type { RuleOperator, FilterLogic } from '../domain/timeline/filteredTimelineStore'
  import { currentLocale, t } from '../infra/i18n'
  import { svelteSignal } from '../ui/svelteSignal.svelte'

  const OPERATORS: RuleOperator[] = ['>', '<', '>=', '<=', '==']

  const configR = svelteSignal(filterConfig)
  const localeR = svelteSignal(currentLocale)

  let newEmoji = $state('')
  let newOp = $state<RuleOperator>('>')
  let newThreshold = $state(0)

  const L = $derived((localeR.value, {
    filterLogic: t('settings.filter_logic'),
    filterEmoji: t('settings.filter_emoji'),
    filterEmojiPlaceholder: t('settings.filter_emoji_placeholder'),
    filterOperator: t('settings.filter_operator'),
    filterThreshold: t('settings.filter_threshold'),
    filterAddRule: t('settings.filter_add_rule'),
    filterNoRules: t('settings.filter_no_rules'),
    actionRemove: t('action.remove'),
  }))

  function handleAdd() {
    if (!newEmoji.trim()) return
    addRule(newEmoji, newOp, newThreshold)
    newEmoji = ''
    newThreshold = 0
  }
</script>

<div class="settings-card">
  <div class="settings-card-row">
    <span class="settings-card-label">{L.filterLogic}</span>
    <div class="settings-radio-group">
      {#each ['AND', 'OR'] as const as l (l)}
        <label>
          <input
            type="radio"
            name="filterLogic"
            value={l}
            checked={configR.value.logic === l}
            onchange={() => setFilterLogic(l as FilterLogic)}
          />
          {l}
        </label>
      {/each}
    </div>
  </div>

  {#if configR.value.rules.length > 0}
    <div class="filter-rules-list">
      {#each configR.value.rules as rule (rule.id)}
        <div class="filter-rule-row">
          <input
            class="filter-rule-emoji"
            type="text"
            value={rule.emoji}
            oninput={(e) => updateRule(rule.id, { emoji: (e.currentTarget as HTMLInputElement).value })}
            aria-label={L.filterEmoji}
          />
          <select
            class="filter-rule-op"
            value={rule.operator}
            onchange={(e) => updateRule(rule.id, { operator: (e.currentTarget as HTMLSelectElement).value as RuleOperator })}
            aria-label={L.filterOperator}
          >
            {#each OPERATORS as op (op)}
              <option value={op}>{op}</option>
            {/each}
          </select>
          <input
            class="filter-rule-threshold"
            type="number"
            min={0}
            value={rule.threshold}
            oninput={(e) => updateRule(rule.id, { threshold: Number((e.currentTarget as HTMLInputElement).value) })}
            aria-label={L.filterThreshold}
          />
          <button
            class="filter-rule-remove"
            type="button"
            aria-label={L.actionRemove}
            onclick={() => removeRule(rule.id)}
          >
            <iconify-icon icon="tabler:x"></iconify-icon>
          </button>
        </div>
      {/each}
    </div>
  {/if}

  <div class="filter-rule-add">
    <input
      class="filter-rule-emoji"
      type="text"
      placeholder={L.filterEmojiPlaceholder}
      value={newEmoji}
      oninput={(e) => { newEmoji = (e.currentTarget as HTMLInputElement).value }}
      onkeydown={(e) => { if (e.key === 'Enter') handleAdd() }}
      aria-label={L.filterEmoji}
    />
    <select
      class="filter-rule-op"
      value={newOp}
      onchange={(e) => { newOp = (e.currentTarget as HTMLSelectElement).value as RuleOperator }}
      aria-label={L.filterOperator}
    >
      {#each OPERATORS as op (op)}
        <option value={op}>{op}</option>
      {/each}
    </select>
    <input
      class="filter-rule-threshold"
      type="number"
      min={0}
      value={newThreshold}
      oninput={(e) => { newThreshold = Number((e.currentTarget as HTMLInputElement).value) }}
      aria-label={L.filterThreshold}
    />
    <button class="filter-rule-add-btn" type="button" onclick={handleAdd}>
      <iconify-icon icon="tabler:plus"></iconify-icon>
      {L.filterAddRule}
    </button>
  </div>

  {#if configR.value.rules.length === 0}
    <p class="filter-rules-empty">{L.filterNoRules}</p>
  {/if}
</div>
