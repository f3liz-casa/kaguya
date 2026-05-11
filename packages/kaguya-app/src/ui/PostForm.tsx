// SPDX-License-Identifier: MPL-2.0

import type { NoteView } from '../domain/note/noteView'
import { usePostComposer } from './postFormHook'
import { client } from '../domain/auth/appState'
import { t } from '../infra/i18n'

type Props = {
  placeholder?: string
  replyTo?: NoteView
  onPosted?: () => void
}

export function PostForm({ placeholder, replyTo, onPosted }: Props) {
  const composer = usePostComposer({ replyTo, onPosted })
  const {
    text, isPosting, visibility, cw, showCw, showVisibilityMenu,
    attachedFiles, uploadingCount, inputRef, fileInputRef,
    setTextValue, setCwValue, toggleCw, toggleVisibilityMenu, setVisibilityAndClose,
    handleSubmit, handleFileChange, handlePaste, removeAttachment, openFilePicker, canAttachMore,
  } = composer

  const isBluesky = client.value?.backend === 'bluesky'

  const visibilityIcons: Record<string, string> = {
    public: 'tabler:world',
    home: 'tabler:home',
    unlisted: 'tabler:home',
    followers: 'tabler:lock',
    private: 'tabler:lock',
    specified: 'tabler:mail',
    direct: 'tabler:mail',
  }
  const visibilityIcon = visibilityIcons[visibility] ?? 'tabler:world'

  return (
    <div class="post-form-container expanded">
      <form onSubmit={handleSubmit}>
        {showCw && (
          <div class="post-form-cw fade-in">
            <input
              type="text"
              placeholder={t('compose.cw_placeholder')}
              value={cw}
              onInput={e => setCwValue((e.target as HTMLInputElement).value)}
              disabled={isPosting}
              class="cw-input"
            />
          </div>
        )}

        <div class="post-form-main">
          <textarea
            ref={inputRef}
            class="post-form-textarea"
            placeholder={placeholder ?? t('compose.placeholder')}
            value={text}
            onInput={e => {
              const target = e.target as HTMLTextAreaElement
              setTextValue(target.value)
              target.style.height = 'auto'
              target.style.height = target.scrollHeight + 'px'
            }}
            onPaste={handlePaste as any}
            disabled={isPosting}
            rows={3}
          />
        </div>

        {attachedFiles.length > 0 && (
          <div class="post-form-attachments fade-in">
            {attachedFiles.map((item, idx) => (
              <div class={`attachment-preview${uploadingCount > 0 ? ' uploading' : ''}`} key={idx}>
                <img src={item.preview} class="attachment-img" alt={t('compose.attachment_alt')} />
                {uploadingCount > 0 ? (
                  <div class="attachment-upload-overlay">
                    <iconify-icon icon="tabler:loader-2" class="attachment-upload-spinner" />
                  </div>
                ) : (
                  <button
                    type="button"
                    class="attachment-remove"
                    onClick={() => removeAttachment(idx)}
                    aria-label={t('action.remove')}
                    disabled={isPosting}
                  >
                    <iconify-icon icon="tabler:x" />
                  </button>
                )}
              </div>
            ))}
          </div>
        )}

        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          multiple
          class="post-form-file-input"
          onChange={handleFileChange as any}
          disabled={isPosting}
        />

        <div class="post-form-footer">
          <div class="post-form-tools">
            {!isBluesky && (
              <button type="button" class={`tool-btn${showCw ? ' active' : ''}`} onClick={toggleCw} title={t('compose.cw_button')}>
                <iconify-icon icon="tabler:eye" />
              </button>
            )}
            <button
              type="button"
              class="tool-btn"
              onClick={openFilePicker}
              title={t('compose.attach_image')}
              aria-label={t('compose.attach_image')}
              disabled={isPosting || !canAttachMore}
            >
              <iconify-icon icon="tabler:photo-plus" />
            </button>

            {!isBluesky && (
              <div class="visibility-selector">
                <button
                  type="button"
                  class="visibility-trigger tool-btn"
                  onClick={toggleVisibilityMenu}
                  disabled={isPosting}
                  title={t('compose.visibility')}
                >
                  <iconify-icon icon={visibilityIcon} />
                  <iconify-icon icon="tabler:chevron-down" class="vis-chevron" />
                </button>
                {showVisibilityMenu && (
                  <ul class="visibility-menu">
                    {(['public', 'home', 'followers'] as const).map(v => (
                      <li key={v}>
                        <button
                          type="button"
                          class={`visibility-option${visibility === v ? ' active' : ''}`}
                          onClick={() => setVisibilityAndClose(v)}
                        >
                          <iconify-icon icon={visibilityIcon} />
                          {v === 'public' ? t('compose.visibility_public') : v === 'home' ? t('compose.visibility_home') : t('compose.visibility_followers')}
                        </button>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            )}
          </div>

          <div class="post-form-actions">
            <button
              type="submit"
              disabled={isPosting || (!text && attachedFiles.length === 0)}
              class="post-btn"
            >
              {isPosting ? (
                <><iconify-icon icon="tabler:loader-2" class="spin" /> {t('compose.sending')}</>
              ) : (
                <><iconify-icon icon="tabler:send" /> {t('compose.submit')}</>
              )}
            </button>
          </div>
        </div>
      </form>
    </div>
  )
}
