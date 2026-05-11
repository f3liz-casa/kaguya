// SPDX-License-Identifier: MPL-2.0

import { addPreconnect, addDnsPrefetch, batchDnsPrefetch, extractOrigin, extractHostname } from 'kaguya-network'
import { asObj, getString, getArray } from './jsonUtils'

export function addPreconnectForInstance(instanceOrigin: string | undefined): void {
  if (instanceOrigin) addPreconnect(instanceOrigin)
}

export function prefetchImageDomain(imageUrl: string): void {
  const origin = extractOrigin(imageUrl)
  if (origin) addDnsPrefetch(origin)
}

export function extractImageDomainsFromNotes(notes: unknown[]): void {
  for (const note of notes) {
    const obj = asObj(note)
    if (!obj) continue
    const files = getArray(obj, 'files')
    if (files) {
      for (const file of files) {
        const fileObj = asObj(file)
        if (!fileObj) continue
        const thumbUrl = getString(fileObj, 'thumbnailUrl')
        if (thumbUrl) prefetchImageDomain(thumbUrl)
        const url = getString(fileObj, 'url')
        if (url) prefetchImageDomain(url)
      }
    }
    const user = asObj(obj['user'] as unknown)
    if (user) {
      const avatarUrl = getString(user, 'avatarUrl')
      if (avatarUrl) prefetchImageDomain(avatarUrl)
    }
  }
}

export function prefetchCommonDomains(instanceOrigin: string): void {
  const hostname = extractHostname(instanceOrigin)
  if (!hostname) return
  batchDnsPrefetch([
    `https://s3.${hostname}`,
    `https://media.${hostname}`,
    `https://files.${hostname}`,
    `https://cdn.${hostname}`,
    `${instanceOrigin}/proxy`,
  ])
}
