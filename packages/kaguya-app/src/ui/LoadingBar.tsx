// SPDX-License-Identifier: MPL-2.0

import { useState, useEffect, useRef } from 'preact/hooks'
import { isLoading } from '../pageLoading'

export function LoadingBar() {
  const loading = isLoading.value
  const [completing, setCompleting] = useState(false)
  const everActiveRef = useRef(false)

  useEffect(() => {
    const el = document.getElementById('initial-bar')
    if (el) el.remove()
  }, [])

  useEffect(() => {
    if (loading) {
      everActiveRef.current = true
      setCompleting(false)
    } else if (everActiveRef.current) {
      everActiveRef.current = false
      setCompleting(true)
      const t = setTimeout(() => setCompleting(false), 600)
      return () => clearTimeout(t)
    }
  }, [loading])

  if (loading) return <div class="page-loading-bar page-loading-bar--active" />
  if (completing) return <div class="page-loading-bar page-loading-bar--completing" />
  return null
}
