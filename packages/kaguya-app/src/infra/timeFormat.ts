// SPDX-License-Identifier: MPL-2.0

export function formatRelativeTime(dateStr: string): string {
  try {
    const date = new Date(dateStr)
    const diffMs = Date.now() - date.getTime()
    const diffSec = diffMs / 1000
    const diffMin = diffSec / 60
    const diffHour = diffMin / 60
    const diffDay = diffHour / 24

    if (diffSec < 60) return 'now'
    if (diffMin < 60) return `${Math.floor(diffMin)}m`
    if (diffHour < 24) return `${Math.floor(diffHour)}h`
    if (diffDay < 7) return `${Math.floor(diffDay)}d`
    return `${date.getMonth() + 1}/${date.getDate()}`
  } catch {
    return ''
  }
}

export function formatFullDate(dateStr: string): string {
  try {
    const date = new Date(dateStr)
    return `${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()}`
  } catch {
    return dateStr
  }
}

export function formatDateTime(dateStr: string): string {
  try {
    const date = new Date(dateStr)
    const pad = (n: number) => n < 10 ? `0${n}` : `${n}`
    return `${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()} ${pad(date.getHours())}:${pad(date.getMinutes())}`
  } catch {
    return dateStr
  }
}
