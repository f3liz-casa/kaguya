// SPDX-License-Identifier: MPL-2.0

// Legacy single-account keys
export const keyOrigin = 'kaguya:instanceOrigin'
export const keyToken = 'kaguya:accessToken'
export const keyMiAuthSession = 'kaguya:miAuthSession'
export const keyMiAuthOrigin = 'kaguya:miAuthOrigin'
export const keyPermissionMode = 'kaguya:permissionMode'

// Multi-account storage keys
export const keyAccounts = 'kaguya:accounts'
export const keyActiveAccountId = 'kaguya:activeAccountId'

// Push notification prefix
export const keyPushUserIdPrefix = 'kaguya:pushUserId:'

// User preferences
export const keyFontSize = 'kaguya:fontSize'
export const keyReduceMotion = 'kaguya:reduceMotion'
export const keyQuietMode = 'kaguya:quietMode'
export const keyQuietHoursEnabled = 'kaguya:quietHours:enabled'
export const keyQuietHoursStart = 'kaguya:quietHours:start'
export const keyQuietHoursEnd = 'kaguya:quietHours:end'
export const keyStreamingEnabled = 'kaguya:streamingEnabled'
export const keyLocale = 'kaguya:locale'
export const keyMediaProxy = 'kaguya:mediaProxy'
export const keyDefaultNoteVisibility = 'kaguya:defaultNoteVisibility'
export const keyDefaultRenoteVisibility = 'kaguya:defaultRenoteVisibility'
export const keyHideNsfw = 'kaguya:hideNsfw'
export const keyInboxDismissed = 'kaguya:inbox:dismissed'
export const keyFilteredTimelineRules = 'kaguya:filteredTimeline:rules'
export const keyFilteredTimelineCache = 'kaguya:filteredTimeline:cache'

// OAuth2 storage keys
export const keyOAuth2CodeVerifier = 'kaguya:oauth2:codeVerifier'
export const keyOAuth2State = 'kaguya:oauth2:state'
export const keyOAuth2Origin = 'kaguya:oauth2:origin'
export const keyOAuth2Scope = 'kaguya:oauth2:scope'
export const keyOAuth2Backend = 'kaguya:oauth2:backend'

const isBrowser = typeof window !== 'undefined'

export function get(key: string): string | undefined {
  if (!isBrowser) return undefined
  return localStorage.getItem(key) ?? undefined
}

export function set(key: string, value: string): void {
  if (!isBrowser) return
  localStorage.setItem(key, value)
}

export function remove(key: string): void {
  if (!isBrowser) return
  localStorage.removeItem(key)
}
