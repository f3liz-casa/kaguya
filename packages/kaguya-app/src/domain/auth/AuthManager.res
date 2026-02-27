// SPDX-License-Identifier: MPL-2.0
// Re-exports for backward compatibility

let restoreSession = AuthService.restoreSession
let login = AuthService.login
let logout = AuthService.logout
let switchAccount = AuthService.switchAccount
let startMiAuth = MiAuthFlow.startMiAuth
let checkMiAuth = MiAuthFlow.checkMiAuth
let startOAuth2 = OAuth2Flow.startOAuth2
let checkOAuth2 = OAuth2Flow.checkOAuth2
