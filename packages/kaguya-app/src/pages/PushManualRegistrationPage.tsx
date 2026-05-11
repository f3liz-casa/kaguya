// SPDX-License-Identifier: MPL-2.0
// Native Misskey push is now handled automatically via PushNotificationToggle.
// This page is no longer needed but kept for backward-compatible redirect.

import { Layout } from '../ui/Layout'
import { Link } from '../ui/router'
import { t } from '../infra/i18n'

export function PushManualRegistrationPage() {
  return (
    <Layout>
      <div style={{ padding: '20px' }}>
        <p>{t('push.migrated')}</p>
        <Link href="/settings">{t('push.back_to_settings')}</Link>
      </div>
    </Layout>
  )
}
