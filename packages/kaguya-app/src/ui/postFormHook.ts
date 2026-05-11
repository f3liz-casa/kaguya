// SPDX-License-Identifier: MPL-2.0

import { useState, useRef, useEffect } from 'preact/hooks'
import type { NoteView } from '../domain/note/noteView'
import type { Visibility } from '../lib/backend'
import * as Backend from '../lib/backend'
import { client } from '../domain/auth/appState'
import { showError, showSuccess } from './toastState'
import { t } from '../infra/i18n'
import { defaultNoteVisibility } from './preferencesStore'

export type Attachment = {
  file: File
  preview: string
}

const MAX_ATTACHMENTS = 4

export type Composer = {
  text: string
  isPosting: boolean
  visibility: Visibility
  cw: string
  showCw: boolean
  showVisibilityMenu: boolean
  attachedFiles: Attachment[]
  uploadingCount: number
  inputRef: { current: HTMLTextAreaElement | null }
  fileInputRef: { current: HTMLInputElement | null }
  setTextValue: (v: string) => void
  setCwValue: (v: string) => void
  toggleCw: () => void
  toggleVisibilityMenu: () => void
  setVisibilityAndClose: (v: Visibility) => void
  handleSubmit: (e: Event) => void
  handleFileChange: (e: Event) => void
  handlePaste: (e: ClipboardEvent) => void
  removeAttachment: (idx: number) => void
  openFilePicker: () => void
  canAttachMore: boolean
}

export function usePostComposer(opts?: { replyTo?: NoteView; onPosted?: () => void }): Composer {
  const [text, setText] = useState('')
  const [isPosting, setIsPosting] = useState(false)
  const [visibility, setVisibility] = useState<Visibility>(defaultNoteVisibility.value)
  const [cw, setCw] = useState('')
  const [showCw, setShowCw] = useState(false)
  const [showVisibilityMenu, setShowVisibilityMenu] = useState(false)
  const [attachedFiles, setAttachedFiles] = useState<Attachment[]>([])
  const [uploadingCount, setUploadingCount] = useState(0)
  const inputRef = useRef<HTMLTextAreaElement | null>(null)
  const fileInputRef = useRef<HTMLInputElement | null>(null)

  const attachedFilesRef = useRef<Attachment[]>([])
  attachedFilesRef.current = attachedFiles
  useEffect(() => () => {
    attachedFilesRef.current.forEach(item => URL.revokeObjectURL(item.preview))
  }, [])

  function addFiles(files: File[]) {
    if (files.length === 0) return
    const remaining = MAX_ATTACHMENTS - attachedFilesRef.current.length
    if (remaining <= 0) return
    const accepted = files.slice(0, remaining)
    const newItems = accepted.map(file => ({ file, preview: URL.createObjectURL(file) }))
    setAttachedFiles(prev => [...prev, ...newItems])
  }

  function removeAttachment(idx: number) {
    setAttachedFiles(prev => {
      URL.revokeObjectURL(prev[idx].preview)
      return prev.filter((_, i) => i !== idx)
    })
  }

  function handleFileChange(e: Event) {
    const input = e.currentTarget as HTMLInputElement
    const files = Array.from(input.files ?? [])
    addFiles(files)
    input.value = ''
  }

  function handlePaste(e: ClipboardEvent) {
    const items = Array.from(e.clipboardData?.items ?? [])
    const imageFiles = items
      .filter(item => item.kind === 'file' && item.type.startsWith('image/'))
      .map(item => item.getAsFile())
      .filter(Boolean) as File[]
    if (imageFiles.length > 0) {
      e.preventDefault()
      addFiles(imageFiles)
    }
  }

  function openFilePicker() {
    fileInputRef.current?.click()
  }

  function handleSubmit(e: Event) {
    e.preventDefault()
    if (!text && attachedFiles.length === 0) return

    void (async () => {
      setIsPosting(true)
      const currentClient = client.value
      if (!currentClient) {
        showError(t('error.not_connected'))
        setIsPosting(false)
        return
      }

      const cwOpt = showCw && cw ? cw : undefined
      const replyId = opts?.replyTo?.id

      let fileIds: string[] | undefined
      if (attachedFiles.length > 0) {
        setUploadingCount(attachedFiles.length)
        const uploadResults = await Promise.all(attachedFiles.map(item => Backend.uploadMedia(currentClient, item.file)))
        setUploadingCount(0)
        const ids = uploadResults.flatMap(r => {
          if (r.ok) return [r.value]
          showError(t('note.image_upload_failed'))
          return []
        })
        if (ids.length > 0) fileIds = ids
      }

      const result = await Backend.createNote(currentClient, text, { visibility, cw: cwOpt, replyId, fileIds })

      if (result.ok) {
        setText('')
        setCw('')
        setShowCw(false)
        attachedFiles.forEach(item => URL.revokeObjectURL(item.preview))
        setAttachedFiles([])
        showSuccess(t('compose.posted'))
        opts?.onPosted?.()
      } else {
        showError(t('note.post_failed'))
      }

      setIsPosting(false)
    })()
  }

  return {
    text, isPosting, visibility, cw, showCw, showVisibilityMenu, attachedFiles, uploadingCount,
    inputRef, fileInputRef,
    setTextValue: setText,
    setCwValue: setCw,
    toggleCw: () => setShowCw(v => !v),
    toggleVisibilityMenu: () => setShowVisibilityMenu(v => !v),
    setVisibilityAndClose: v => { setVisibility(v); setShowVisibilityMenu(false) },
    handleSubmit, handleFileChange, handlePaste, removeAttachment, openFilePicker,
    canAttachMore: attachedFiles.length < MAX_ATTACHMENTS,
  }
}
