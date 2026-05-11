// SPDX-License-Identifier: MPL-2.0

import { useState, useRef, useEffect } from 'preact/hooks'
import { Layout } from '../ui/Layout'
import { NoteViewComponent } from '../domain/note/Note'
import { ContentRenderer } from '../ui/content/ContentRenderer'
import { client, isLoggedIn, isReadOnlyMode, currentUser } from '../domain/auth/appState'
import { decode as decodeProfile, displayName as profileDisplayName, fullUsername } from '../domain/user/userProfileView'
import { decode as decodeNote, decodeManyFromJson } from '../domain/note/noteDecoder'
import * as Backend from '../lib/backend'
import type { NoteView } from '../domain/note/noteView'
import type { UserProfileView } from '../domain/user/userProfileView'
import { userFilters, setUserFilter } from '../domain/user/userFilterStore'
import { t } from '../infra/i18n'
import { proxyUrl, proxyAvatarUrl } from '../infra/mediaProxy'
import { showError } from '../ui/toastState'
import { asObj, getString } from '../infra/jsonUtils'

type PageState =
  | { type: 'Loading' }
  | {
      type: 'Loaded'
      profile: UserProfileView
      pinnedNotes: NoteView[]
      notes: NoteView[]
      lastNoteId: string | undefined
      hasMore: boolean
      isLoadingMore: boolean
    }
  | { type: 'Error'; message: string }

function formatCount(n: number): string {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M'
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'K'
  return String(n)
}

type Props = { username: string; host?: string }

export function UserPage({ username, host }: Props) {
  const [state, setState] = useState<PageState>({ type: 'Loading' })
  const [isFollowing, setIsFollowing] = useState(false)
  const [isFollowLoading, setIsFollowLoading] = useState(false)
  const sentinelRef = useRef<HTMLDivElement | null>(null)

  useEffect(() => {
    setState({ type: 'Loading' })
    const currentClient = client.value
    if (!currentClient) {
      setState({ type: 'Error', message: t('error.not_connected') })
      return
    }
    void (async () => {
      const profileResult = await Backend.showUser(currentClient, { username, host })
      if (!profileResult.ok) {
        setState({ type: 'Error', message: profileResult.error })
        return
      }
      const profile = decodeProfile(profileResult.value)
      if (!profile) {
        setState({ type: 'Error', message: t('user.decode_failed') })
        return
      }

      const pinnedPromises = profile.pinnedNoteIds.map(async noteId => {
        const r = await Backend.showNote(currentClient, noteId)
        return r.ok ? decodeNote(r.value) : undefined
      })
      const [notesResult, pinnedResults] = await Promise.all([
        Backend.userNotes(currentClient,profile.id),
        Promise.all(pinnedPromises),
      ])
      const pinnedNotes = pinnedResults.filter((n): n is NoteView => !!n)
      const notes = notesResult.ok ? decodeManyFromJson(notesResult.value) : []
      setIsFollowing(profile.isFollowing)
      setState({
        type: 'Loaded',
        profile,
        pinnedNotes,
        notes,
        lastNoteId: notes.at(-1)?.id,
        hasMore: notes.length >= 20,
        isLoadingMore: false,
      })
    })()
  }, [username, host])

  async function handleFollow() {
    if (state.type !== 'Loaded' || isFollowLoading) return
    const currentClient = client.value
    if (!currentClient) return
    setIsFollowLoading(true)
    if (isFollowing) {
      const result = await Backend.unfollow(currentClient, state.profile.id)
      if (result.ok) setIsFollowing(false)
      else showError(t('user.unfollow_failed'))
    } else {
      const result = await Backend.follow(currentClient, state.profile.id)
      if (result.ok) setIsFollowing(true)
      else showError(t('user.follow_failed'))
    }
    setIsFollowLoading(false)
  }

  async function loadMore() {
    if (state.type !== 'Loaded' || !state.hasMore || state.isLoadingMore || !state.lastNoteId) return
    const currentClient = client.value
    if (!currentClient) return
    setState({ ...state, isLoadingMore: true })
    const result = await Backend.userNotes(currentClient,state.profile.id, { untilId: state.lastNoteId })
    if (result.ok) {
      const newNotes = decodeManyFromJson(result.value)
      const allNotes = [...state.notes, ...newNotes]
      setState({ ...state, notes: allNotes, lastNoteId: newNotes.at(-1)?.id, hasMore: newNotes.length >= 20, isLoadingMore: false })
    } else {
      setState({ ...state, isLoadingMore: false })
    }
  }

  useEffect(() => {
    const el = sentinelRef.current
    if (!el) return
    const obs = new IntersectionObserver(entries => {
      if (entries[0]?.isIntersecting) void loadMore()
    }, { threshold: 0.1 })
    obs.observe(el)
    return () => obs.disconnect()
  }, [state])

  return (
    <Layout>
      {state.type === 'Loading' ? (
        <div class="loading-container"><p>{t('app.loading')}</p></div>
      ) : state.type === 'Error' ? (
        <div class="user-error"><p>{state.message}</p></div>
      ) : (
        <div class="user-profile-container">
          {state.profile.bannerUrl ? (
            <div class="user-banner">
              <img src={proxyUrl(state.profile.bannerUrl)} alt="" class="user-banner-image" loading="lazy" />
            </div>
          ) : (
            <div class="user-banner user-banner-empty" />
          )}

          <div class="user-profile-header">
            <div class="user-avatar-section">
              {state.profile.avatarUrl ? (
                <img class="user-avatar" src={proxyAvatarUrl(state.profile.avatarUrl)} alt={`${state.profile.username}'s avatar`} loading="lazy" />
              ) : (
                <div class="user-avatar user-avatar-placeholder" />
              )}
            </div>
            <div class="user-info">
              <h1 class="user-display-name">
                <ContentRenderer text={profileDisplayName(state.profile)} parseSimple />
              </h1>
              <span class="user-username">{fullUsername(state.profile)}</span>
              {state.profile.isBot && <span class="user-bot-badge">🤖 Bot</span>}
              {isLoggedIn.value && !isReadOnlyMode() && (() => {
                const me = asObj(currentUser.value)
                const myId = me ? getString(me, 'id') : undefined
                return myId !== state.profile.id
              })() && (
                <button
                  class={`user-follow-btn${isFollowing ? ' user-follow-btn-following' : ''}`}
                  onClick={() => void handleFollow()}
                  disabled={isFollowLoading}
                  type="button"
                >
                  {isFollowing ? t('user.unfollow') : t('user.follow')}
                </button>
              )}
            </div>
            <div class="user-stats">
              <div class="user-stat">
                <span class="user-stat-value" title={String(state.profile.notesCount)}>{formatCount(state.profile.notesCount)}</span>
                <span class="user-stat-label">{t('user.stat_notes')}</span>
              </div>
              <div class="user-stat">
                <span class="user-stat-value" title={String(state.profile.followingCount)}>{formatCount(state.profile.followingCount)}</span>
                <span class="user-stat-label">{t('user.stat_following')}</span>
              </div>
              <div class="user-stat">
                <span class="user-stat-value" title={String(state.profile.followersCount)}>{formatCount(state.profile.followersCount)}</span>
                <span class="user-stat-label">{t('user.stat_followers')}</span>
              </div>
            </div>
          </div>

          <UserFilterControls userId={state.profile.id} />

          {state.profile.description && (
            <div class="user-bio">
              <ContentRenderer text={state.profile.description} />
            </div>
          )}

          {state.profile.fields.length > 0 && (
            <div class="user-fields">
              {state.profile.fields.map((field, idx) => (
                <div key={idx} class="user-field">
                  <span class="user-field-name"><ContentRenderer text={field.fieldName} parseSimple /></span>
                  <span class="user-field-value"><ContentRenderer text={field.fieldValue} /></span>
                </div>
              ))}
            </div>
          )}

          {state.pinnedNotes.length > 0 && (
            <div class="user-pinned-notes">
              <h3 class="user-section-title">📌 {t('user.pinned_notes')}</h3>
              <div class="timeline-notes">
                {state.pinnedNotes.map(note => <NoteViewComponent key={note.id} note={note} />)}
              </div>
            </div>
          )}

          <div class="user-notes-section">
            <h3 class="user-section-title">{t('user.section_notes')}</h3>
            {state.notes.length === 0 ? (
              <div class="timeline-empty"><p>{t('user.no_notes')}</p></div>
            ) : (
              <>
                <div class="timeline-notes">
                  {state.notes.map(note => <NoteViewComponent key={note.id} note={note} />)}
                </div>
                {state.hasMore ? (
                  <>
                    <div ref={sentinelRef} class="timeline-sentinel" />
                    {state.isLoadingMore && (
                      <div class="timeline-loading-more"><p>{t('app.loading')}</p></div>
                    )}
                  </>
                ) : (
                  <div class="timeline-end"><p>{t('user.no_more')}</p></div>
                )}
              </>
            )}
          </div>
        </div>
      )}
    </Layout>
  )
}

function UserFilterControls({ userId }: { userId: string }) {
  const filter = userFilters.value.find(f => f.userId === userId)

  function handleImagesOnly(e: Event) {
    const checked = (e.target as HTMLInputElement).checked
    setUserFilter({ userId, imagesOnly: checked, noRenotes: filter?.noRenotes ?? false })
  }

  function handleNoRenotes(e: Event) {
    const checked = (e.target as HTMLInputElement).checked
    setUserFilter({ userId, imagesOnly: filter?.imagesOnly ?? false, noRenotes: checked })
  }

  return (
    <div class="user-filter">
      <label class="user-filter-option">
        <input
          type="checkbox"
          checked={filter?.imagesOnly ?? false}
          onChange={handleImagesOnly}
        />
        {t('user_filter.images_only')}
      </label>
      <label class="user-filter-option">
        <input
          type="checkbox"
          checked={filter?.noRenotes ?? false}
          onChange={handleNoRenotes}
        />
        {t('user_filter.no_renotes')}
      </label>
    </div>
  )
}
