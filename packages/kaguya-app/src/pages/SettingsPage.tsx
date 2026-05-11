// SPDX-License-Identifier: MPL-2.0

import { Layout } from '../ui/Layout'
import { AccountSwitcher } from '../domain/account/AccountSwitcher'
import { PushNotificationToggle } from '../ui/PushNotificationToggle'
import { currentTheme, setTheme } from '../ui/themeStore'
import type { Theme } from '../ui/themeStore'
import {
  fontSize,
  reduceMotion,
  streamingEnabled,
  quietMode,
  quietHoursEnabled,
  quietHoursStart,
  quietHoursEnd,
  setFontSize,
  setReduceMotion,
  setStreamingEnabled,
  setQuietMode,
  setQuietHoursEnabled,
  setQuietHoursStart,
  setQuietHoursEnd,
  defaultNoteVisibility,
  defaultRenoteVisibility,
  setDefaultNoteVisibility,
  setDefaultRenoteVisibility,
  hideNsfw,
  setHideNsfw,
} from '../ui/preferencesStore'
import type { FontSize } from '../ui/preferencesStore'
import type { Visibility } from '../lib/backend'
import { t, currentLocale, setLocale } from '../infra/i18n'
import type { Locale } from '../infra/i18n'
import { mediaProxyEnabled, setMediaProxy } from '../infra/mediaProxy'
import { cacheEmojisForeground, isLoaded as emojiIsLoaded, isLoading as emojiIsLoading, emojiCount, cacheProgress } from '../domain/emoji/emojiStore'
import { client } from '../domain/auth/appState'
import { useState } from 'preact/hooks'
import {
  filterConfig,
  addRule,
  removeRule,
  updateRule,
  setFilterLogic,
} from '../domain/timeline/filteredTimelineStore'
import type { RuleOperator, FilterLogic } from '../domain/timeline/filteredTimelineStore'

const OPERATORS: RuleOperator[] = ['>', '<', '>=', '<=', '==']

function FilteredTimelineSection() {
  const config = filterConfig.value
  const [newEmoji, setNewEmoji] = useState('')
  const [newOp, setNewOp] = useState<RuleOperator>('>')
  const [newThreshold, setNewThreshold] = useState(0)

  function handleAdd() {
    if (!newEmoji.trim()) return
    addRule(newEmoji, newOp, newThreshold)
    setNewEmoji('')
    setNewThreshold(0)
  }

  return (
    <div class="settings-card">
      <div class="settings-card-row">
        <span class="settings-card-label">{t('settings.filter_logic')}</span>
        <div class="settings-radio-group">
          {(['AND', 'OR'] as FilterLogic[]).map(l => (
            <label key={l}>
              <input
                type="radio"
                name="filterLogic"
                value={l}
                checked={config.logic === l}
                onChange={() => setFilterLogic(l)}
              />
              {l}
            </label>
          ))}
        </div>
      </div>

      {config.rules.length > 0 && (
        <div class="filter-rules-list">
          {config.rules.map(rule => (
            <div key={rule.id} class="filter-rule-row">
              <input
                class="filter-rule-emoji"
                type="text"
                value={rule.emoji}
                onInput={e => updateRule(rule.id, { emoji: (e.target as HTMLInputElement).value })}
                aria-label={t('settings.filter_emoji')}
              />
              <select
                class="filter-rule-op"
                value={rule.operator}
                onChange={e => updateRule(rule.id, { operator: (e.target as HTMLSelectElement).value as RuleOperator })}
                aria-label={t('settings.filter_operator')}
              >
                {OPERATORS.map(op => <option key={op} value={op}>{op}</option>)}
              </select>
              <input
                class="filter-rule-threshold"
                type="number"
                min={0}
                value={rule.threshold}
                onInput={e => updateRule(rule.id, { threshold: Number((e.target as HTMLInputElement).value) })}
                aria-label={t('settings.filter_threshold')}
              />
              <button
                class="filter-rule-remove"
                type="button"
                onClick={() => removeRule(rule.id)}
                aria-label={t('action.remove')}
              >
                <iconify-icon icon="tabler:x" />
              </button>
            </div>
          ))}
        </div>
      )}

      <div class="filter-rule-add">
        <input
          class="filter-rule-emoji"
          type="text"
          placeholder={t('settings.filter_emoji_placeholder')}
          value={newEmoji}
          onInput={e => setNewEmoji((e.target as HTMLInputElement).value)}
          onKeyDown={e => { if (e.key === 'Enter') handleAdd() }}
          aria-label={t('settings.filter_emoji')}
        />
        <select
          class="filter-rule-op"
          value={newOp}
          onChange={e => setNewOp((e.target as HTMLSelectElement).value as RuleOperator)}
          aria-label={t('settings.filter_operator')}
        >
          {OPERATORS.map(op => <option key={op} value={op}>{op}</option>)}
        </select>
        <input
          class="filter-rule-threshold"
          type="number"
          min={0}
          value={newThreshold}
          onInput={e => setNewThreshold(Number((e.target as HTMLInputElement).value))}
          aria-label={t('settings.filter_threshold')}
        />
        <button
          class="filter-rule-add-btn"
          type="button"
          onClick={handleAdd}
        >
          <iconify-icon icon="tabler:plus" />
          {t('settings.filter_add_rule')}
        </button>
      </div>

      {config.rules.length === 0 && (
        <p class="filter-rules-empty">{t('settings.filter_no_rules')}</p>
      )}
    </div>
  )
}

function handleClearData() {
  const confirmed = window.confirm(t('settings.clear_all_confirm'))
  if (confirmed) {
    localStorage.clear()
    window.location.reload()
  }
}

const visibilityOptions: { value: Visibility; labelKey: string }[] = [
  { value: 'public', labelKey: 'compose.visibility_public' },
  { value: 'home', labelKey: 'compose.visibility_home' },
  { value: 'followers', labelKey: 'compose.visibility_followers' },
  { value: 'specified', labelKey: 'compose.visibility_specified' },
]

export function SettingsPage() {
  const currentFontSize = fontSize.value
  const currentReduceMotion = reduceMotion.value
  const currentStreaming = streamingEnabled.value
  const currentQuietManual = quietMode.value
  const currentQuietHoursEnabled = quietHoursEnabled.value
  const currentQuietHoursStart = quietHoursStart.value
  const currentQuietHoursEnd = quietHoursEnd.value
  const theme = currentTheme.value
  const locale = currentLocale.value
  const currentMediaProxy = mediaProxyEnabled.value
  const currentHideNsfw = hideNsfw.value
  const currentNoteVisibility = defaultNoteVisibility.value
  const currentRenoteVisibility = defaultRenoteVisibility.value

  return (
    <Layout>
      <div class="settings-page">
        <h2 class="settings-title">{t('settings.title')}</h2>

        <section class="settings-section">
          <h3 class="settings-section-title">{t('settings.section_account')}</h3>
          <div class="settings-card">
            <AccountSwitcher />
          </div>
        </section>

        <section class="settings-section">
          <h3 class="settings-section-title">{t('settings.section_notifications')}</h3>
          <div class="settings-card settings-card-row">
            <span class="settings-card-label">{t('settings.push_notifications')}</span>
            <PushNotificationToggle />
          </div>
        </section>

        <section class="settings-section">
          <h3 class="settings-section-title">{t('settings.section_posting')}</h3>
          <div class="settings-card">
            <div class="settings-card-row">
              <span class="settings-card-label">{t('settings.default_note_visibility')}</span>
              <div class="settings-radio-group">
                {visibilityOptions.map(({ value, labelKey }) => (
                  <label key={value}>
                    <input
                      type="radio"
                      name="defaultNoteVisibility"
                      value={value}
                      checked={currentNoteVisibility === value}
                      onChange={() => setDefaultNoteVisibility(value)}
                    />
                    {t(labelKey)}
                  </label>
                ))}
              </div>
            </div>
            <div class="settings-card-row">
              <span class="settings-card-label">{t('settings.default_renote_visibility')}</span>
              <div class="settings-radio-group">
                {visibilityOptions.map(({ value, labelKey }) => (
                  <label key={value}>
                    <input
                      type="radio"
                      name="defaultRenoteVisibility"
                      value={value}
                      checked={currentRenoteVisibility === value}
                      onChange={() => setDefaultRenoteVisibility(value)}
                    />
                    {t(labelKey)}
                  </label>
                ))}
              </div>
            </div>
          </div>
        </section>

        <section class="settings-section">
          <h3 class="settings-section-title">{t('settings.section_filtered_timeline')}</h3>
          <p class="settings-section-description">{t('settings.filtered_timeline_description')}</p>
          <FilteredTimelineSection />
        </section>

        <section class="settings-section">
          <h3 class="settings-section-title">{t('settings.section_display')}</h3>
          <div class="settings-card">
            <div class="settings-card-row">
              <span class="settings-card-label">{t('settings.font_size')}</span>
              <div class="settings-radio-group">
                {(['small', 'medium', 'large'] as FontSize[]).map(size => (
                  <label key={size}>
                    <input
                      type="radio"
                      name="fontSize"
                      value={size}
                      checked={currentFontSize === size}
                      onChange={() => setFontSize(size)}
                    />
                    {size === 'small' ? t('settings.font_small') : size === 'medium' ? t('settings.font_medium') : t('settings.font_large')}
                  </label>
                ))}
              </div>
            </div>
            <div class="settings-toggle-row">
              <span class="settings-card-label">{t('settings.reduce_motion')}</span>
              <label>
                <input
                  type="checkbox"
                  checked={currentReduceMotion}
                  onChange={e => setReduceMotion((e.target as HTMLInputElement).checked)}
                />
              </label>
            </div>
            <div class="settings-toggle-row">
              <div>
                <span class="settings-card-label">{t('settings.streaming')}</span>
                <small class="settings-about">{t('settings.streaming_description')}</small>
              </div>
              <label>
                <input
                  type="checkbox"
                  checked={currentStreaming}
                  onChange={e => setStreamingEnabled((e.target as HTMLInputElement).checked)}
                />
              </label>
            </div>
            <div class="settings-toggle-row">
              <div>
                <span class="settings-card-label">{t('settings.media_proxy')}</span>
                <small class="settings-about">{t('settings.media_proxy_description')}</small>
              </div>
              <label>
                <input
                  type="checkbox"
                  checked={currentMediaProxy}
                  onChange={e => setMediaProxy((e.target as HTMLInputElement).checked)}
                />
              </label>
            </div>
            <div class="settings-toggle-row">
              <div>
                <span class="settings-card-label">{t('settings.hide_nsfw')}</span>
                <small class="settings-about">{t('settings.hide_nsfw_description')}</small>
              </div>
              <label>
                <input
                  type="checkbox"
                  checked={currentHideNsfw}
                  onChange={e => setHideNsfw((e.target as HTMLInputElement).checked)}
                />
              </label>
            </div>
          </div>
        </section>

        <section class="settings-section">
          <h3 class="settings-section-title">{t('settings.section_quiet')}</h3>
          <div class="settings-card">
            <div class="settings-toggle-row">
              <div>
                <span class="settings-card-label">{t('settings.quiet_manual')}</span>
                <small class="settings-about">{t('settings.quiet_manual_description')}</small>
              </div>
              <label>
                <input
                  type="checkbox"
                  checked={currentQuietManual}
                  onChange={e => setQuietMode((e.target as HTMLInputElement).checked)}
                />
              </label>
            </div>
            <div class="settings-toggle-row">
              <div>
                <span class="settings-card-label">{t('settings.quiet_hours')}</span>
                <small class="settings-about">{t('settings.quiet_hours_description')}</small>
              </div>
              <label>
                <input
                  type="checkbox"
                  checked={currentQuietHoursEnabled}
                  onChange={e => setQuietHoursEnabled((e.target as HTMLInputElement).checked)}
                />
              </label>
            </div>
            {currentQuietHoursEnabled && (
              <div class="settings-card-row settings-quiet-hours-row">
                <span class="settings-card-label">{t('settings.quiet_hours_range')}</span>
                <div class="settings-quiet-hours-inputs">
                  <input
                    type="time"
                    value={currentQuietHoursStart}
                    onChange={e => setQuietHoursStart((e.target as HTMLInputElement).value)}
                    aria-label={t('settings.quiet_hours_start')}
                  />
                  <span class="settings-quiet-hours-sep">–</span>
                  <input
                    type="time"
                    value={currentQuietHoursEnd}
                    onChange={e => setQuietHoursEnd((e.target as HTMLInputElement).value)}
                    aria-label={t('settings.quiet_hours_end')}
                  />
                </div>
              </div>
            )}
          </div>
        </section>

        <section class="settings-section">
          <h3 class="settings-section-title">{t('settings.section_theme')}</h3>
          <div class="settings-card">
            <div class="settings-radio-group">
              {([['System', 'theme.system'], ['Light', 'theme.light'], ['Dark', 'theme.dark']] as const).map(([value, key]) => (
                <label key={value}>
                  <input
                    type="radio"
                    name="theme"
                    value={value}
                    checked={theme === value}
                    onChange={() => setTheme(value as Theme)}
                  />
                  {t(key)}
                </label>
              ))}
            </div>
          </div>
        </section>

        <section class="settings-section">
          <h3 class="settings-section-title">{t('settings.section_language')}</h3>
          <div class="settings-card">
            <div class="settings-radio-group">
              {([['ja', '日本語'], ['en', 'English']] as const).map(([value, label]) => (
                <label key={value}>
                  <input
                    type="radio"
                    name="locale"
                    value={value}
                    checked={locale === value}
                    onChange={() => setLocale(value as Locale)}
                  />
                  {label}
                </label>
              ))}
            </div>
          </div>
        </section>

        <section class="settings-section">
          <h3 class="settings-section-title">{t('settings.section_cache')}</h3>
          <div class="settings-card">
            <div class="settings-card-row">
              <div>
                <span class="settings-card-label">{t('settings.cache_emoji')}</span>
                <small class="settings-about">{t('settings.cache_emoji_description')}</small>
              </div>
              <button
                type="button"
                class="settings-btn"
                disabled={!!cacheProgress.value}
                onClick={() => {
                  const bc = client.value
                  if (bc?.backend === 'misskey') {
                    void cacheEmojisForeground(bc.client)
                  }
                }}
              >
                {cacheProgress.value
                  ? t('settings.cache_emoji_loading')
                  : emojiIsLoaded.value
                    ? `${t('settings.cache_emoji_done')} (${emojiCount.value})`
                    : t('settings.cache_emoji_btn')}
              </button>
            </div>
            {cacheProgress.value && (
              <div class="settings-cache-progress">
                <div class="settings-cache-progress-bar">
                  <div
                    class="settings-cache-progress-fill"
                    style={{ width: `${(cacheProgress.value.done / cacheProgress.value.total) * 100}%` }}
                  />
                </div>
                <small class="settings-cache-progress-text">
                  {cacheProgress.value.done} / {cacheProgress.value.total}
                </small>
              </div>
            )}
          </div>
        </section>

        <section class="settings-section">
          <h3 class="settings-section-title">{t('settings.section_data')}</h3>
          <div class="settings-card">
            <button
              type="button"
              class="settings-danger-btn"
              onClick={handleClearData}
            >
              {t('settings.clear_all_data')}
            </button>
          </div>
        </section>

        <section class="settings-section">
          <h3 class="settings-section-title">{t('settings.section_about')}</h3>
          <div class="settings-card">
            <div class="settings-about">
              <p>{t('app.tagline')}</p>
              <p>{t('settings.about_privacy')}</p>
            </div>
          </div>
        </section>
      </div>
    </Layout>
  )
}
