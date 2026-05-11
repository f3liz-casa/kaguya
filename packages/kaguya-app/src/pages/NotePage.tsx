// SPDX-License-Identifier: MPL-2.0

import { useState, useRef, useEffect } from 'preact/hooks'
import { useSignalEffect } from '@preact/signals'
import { Layout } from '../ui/Layout'
import { NoteViewComponent } from '../domain/note/Note'
import { PostForm } from '../ui/PostForm'
import { client, authState, instanceName } from '../domain/auth/appState'
import { decode as decodeNote, decodeManyFromJson } from '../domain/note/noteDecoder'
import * as Backend from '../lib/backend'
import type { BackendClient } from '../lib/backend'
import type { Result } from '../infra/result'
import { ok, err } from '../infra/result'
import { start as loadingStart, done_ as loadingDone } from '../pageLoading'
import { useLocation } from '../ui/router'
import type { NoteView } from '../domain/note/noteView'
import { consumePrefetch, consumeSwPreview } from '../infra/notePrefetch'
import { t } from '../infra/i18n'
import { proxyAvatarUrl } from '../infra/mediaProxy'

type NotePreview = { text: string; userName: string; userUsername: string; avatarUrl: string }

type PageState =
  | { type: 'Loading' }
  | { type: 'Preview'; preview: NotePreview }
  | { type: 'Loaded'; note: NoteView; conversation: NoteView[] | null; replies: NoteView[] | null }
  | { type: 'Error'; message: string }

type ResolvedNote = { localId: string; json: unknown }

async function resolveNote(
  c: BackendClient,
  noteId: string,
  host: string,
  localHost: string,
): Promise<Result<ResolvedNote>> {
  if (host === localHost) {
    const prefetched = await consumePrefetch(noteId)
    if (prefetched) return ok({ localId: noteId, json: prefetched })

    const result = await Backend.showNote(c, noteId)
    if (result.ok) return ok({ localId: noteId, json: result.value })
    return err(result.error)
  }
  const remoteUri = `https://${host}/notes/${noteId}`
  const apResult = await Backend.rawRequest(c, 'ap/show', { uri: remoteUri })
  if (!apResult.ok) return err(`${t('note_page.remote_fetch_failed')}: ${apResult.error}`)
  const obj = apResult.value as Record<string, unknown>
  if (obj?.type === 'Note' && obj?.object) {
    const noteJson = obj.object as Record<string, unknown>
    const localId = (noteJson?.id as string) ?? noteId
    return ok({ localId, json: noteJson })
  }
  return err(t('note_page.remote_resolve_failed'))
}

type Props = { noteId: string; host: string }

export function NotePage({ noteId: rawNoteId, host }: Props) {
  // AT URIs (at://did:plc:xxx/...) are URL-encoded in the path
  const noteId = decodeURIComponent(rawNoteId)
  const [state, setState] = useState<PageState>({ type: 'Loading' })
  const [, navigate] = useLocation()
  const mainNoteRef = useRef<HTMLDivElement | null>(null)

  useEffect(() => {
    if (state.type === 'Loaded') {
      mainNoteRef.current?.scrollIntoView({ behavior: 'instant' as ScrollBehavior })
    }
  }, [state.type])

  useSignalEffect(() => {
    const currentClient = client.value
    const currentAuthState = authState.value
    const localHost = instanceName.value

    // Defer signal writes to avoid cycle (useSignalEffect is tracking above reads)
    queueMicrotask(() => {
      setState({ type: 'Loading' })
      loadingStart()
    })

    let done = false
    function callDone() {
      if (!done) { done = true; loadingDone() }
    }

    void (async () => {
      if (!currentClient) {
        if (currentAuthState !== 'LoggingIn') {
          callDone()
          setState({ type: 'Error', message: t('error.not_connected') })
        } else {
          // While waiting for auth, show SW-cached preview if available
          const preview = await consumeSwPreview(noteId)
          if (preview) setState({ type: 'Preview', preview })
        }
        return
      }

      const resolved = await resolveNote(currentClient, noteId, host, localHost)
      if (!resolved.ok) {
        callDone()
        setState({ type: 'Error', message: resolved.error })
        return
      }

      const { localId, json } = resolved.value
      if (host !== localHost) {
        callDone()
        navigate(`/notes/${encodeURIComponent(localId)}/${localHost}`)
        return
      }

      const note = decodeNote(json)
      if (!note) {
        callDone()
        setState({ type: 'Error', message: t('note_page.decode_failed') })
        return
      }

      // Show main note immediately — conversation/replies load progressively
      callDone()
      setState({ type: 'Loaded', note, conversation: null, replies: null })

      const [convResult, repliesResult] = await Promise.all([
        Backend.noteContext(currentClient, localId),
        Backend.noteChildren(currentClient, localId),
      ])
      const conversation = convResult.ok ? decodeManyFromJson(convResult.value).reverse() : []
      const replies = repliesResult.ok ? decodeManyFromJson(repliesResult.value) : []
      setState(prev => prev.type === 'Loaded' && prev.note.id === note.id
        ? { type: 'Loaded', note, conversation, replies }
        : prev
      )
    })()

    return () => callDone()
  })

  return (
    <Layout>
      {state.type === 'Loading' ? (
        <div class="timeline-skeleton">
          <div class="skeleton-note">
            <div class="skeleton-avatar" />
            <div class="skeleton-content">
              <div class="skeleton-line skeleton-line-name" />
              <div class="skeleton-line skeleton-line-long" />
              <div class="skeleton-line skeleton-line-medium" />
            </div>
          </div>
          <div class="skeleton-note">
            <div class="skeleton-avatar" />
            <div class="skeleton-content">
              <div class="skeleton-line skeleton-line-name" />
              <div class="skeleton-line skeleton-line-long" />
              <div class="skeleton-line skeleton-line-medium" />
            </div>
          </div>
        </div>
      ) : state.type === 'Preview' ? (
        <div class="note-page-container">
          <div class="note-page-main note-preview-shimmer">
            <div class="note-card">
              <div class="note-header">
                {state.preview.avatarUrl && <img class="note-avatar" src={proxyAvatarUrl(state.preview.avatarUrl)} alt="" width={48} height={48} />}
                <span class="note-display-name">{state.preview.userName}</span>
                <span class="note-username">@{state.preview.userUsername}</span>
              </div>
              <div class="note-body"><p>{state.preview.text}</p></div>
            </div>
          </div>
        </div>
      ) : state.type === 'Error' ? (
        <div class="note-page-error">
          <p>{state.message}</p>
        </div>
      ) : (
        <div class="note-page-container">
          {state.note.uri && (
            <div class="note-remote-warning" role="status">
              <p>⚠ {t('note_page.remote_warning')}</p>
              <a href={state.note.uri} target="_blank" rel="noopener noreferrer" class="note-original-link">
                {t('note_page.view_original')}
              </a>
            </div>
          )}

          {state.conversation === null ? (
            <div class="timeline-skeleton">
              <div class="skeleton-note">
                <div class="skeleton-avatar" />
                <div class="skeleton-content">
                  <div class="skeleton-line skeleton-line-name" />
                  <div class="skeleton-line skeleton-line-medium" />
                </div>
              </div>
            </div>
          ) : state.conversation.length > 0 ? (
            <div class="note-conversation">
              <div class="timeline-notes">
                {state.conversation.map(n => <NoteViewComponent key={n.id} note={n} />)}
              </div>
              <div class="note-thread-connector" />
            </div>
          ) : null}

          <div class="note-page-main" ref={mainNoteRef}>
            <NoteViewComponent note={state.note} />
          </div>

          <PostForm replyTo={state.note} placeholder={t('compose.reply_placeholder')} />

          {state.replies === null ? (
            <div class="timeline-skeleton">
              <div class="skeleton-note">
                <div class="skeleton-avatar" />
                <div class="skeleton-content">
                  <div class="skeleton-line skeleton-line-name" />
                  <div class="skeleton-line skeleton-line-medium" />
                </div>
              </div>
            </div>
          ) : state.replies.length > 0 ? (
            <div class="note-replies">
              <h3 class="note-replies-title">{t('note.section_replies')}</h3>
              <div class="timeline-notes">
                {state.replies.map(n => <NoteViewComponent key={n.id} note={n} />)}
              </div>
            </div>
          ) : null}
        </div>
      )}
    </Layout>
  )
}
