// SPDX-License-Identifier: MPL-2.0

import { t } from '../../infra/i18n'

export type LoginError =
  | { type: 'InvalidCredentials' }
  | { type: 'NetworkError'; message: string }
  | { type: 'UnknownError'; message: string }
  | { type: 'SessionExpired' }

export type AuthState =
  | 'LoggedOut'
  | 'LoggingIn'
  | 'LoggedIn'
  | { type: 'LoginFailed'; error: LoginError }

export type PermissionMode = 'ReadOnly' | 'Standard'

export function loginErrorMessage(err: LoginError): string {
  switch (err.type) {
    case 'InvalidCredentials': return t('error.invalid_credentials')
    case 'NetworkError': return t('error.network')
    case 'UnknownError': return t('error.unknown')
    case 'SessionExpired': return t('auth.session_expired')
  }
}
