// SPDX-License-Identifier: MPL-2.0

import { signal, batch } from '@preact/signals'
import type { Result } from '../../infra/result'

export const antennas = signal<unknown[]>([])
export const lists = signal<unknown[]>([])
export const channels = signal<unknown[]>([])
export const feeds = signal<unknown[]>([])
export const homeTimelineInitial = signal<unknown | undefined>(undefined)

export function clear(): void {
  batch(() => {
    antennas.value = []
    lists.value = []
    channels.value = []
    feeds.value = []
    homeTimelineInitial.value = undefined
  })
}

export function setFromInitData(opts: {
  antennasResult: Result<unknown[]>
  listsResult: Result<unknown[]>
  channelsResult: Result<unknown[]>
  feedsResult?: Result<unknown[]>
  homeTimelineResult?: Result<unknown>
}): void {
  batch(() => {
    if (opts.antennasResult.ok) antennas.value = opts.antennasResult.value
    if (opts.listsResult.ok) lists.value = opts.listsResult.value
    if (opts.channelsResult.ok) channels.value = opts.channelsResult.value
    if (opts.feedsResult?.ok) feeds.value = opts.feedsResult.value
    if (opts.homeTimelineResult?.ok) homeTimelineInitial.value = opts.homeTimelineResult.value
  })
}
