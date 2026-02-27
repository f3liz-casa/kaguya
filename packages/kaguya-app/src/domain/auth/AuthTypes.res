// SPDX-License-Identifier: MPL-2.0

type loginError =
  | InvalidCredentials
  | NetworkError(string)
  | UnknownError(string)

type authState =
  | LoggedOut
  | LoggingIn
  | LoggedIn
  | LoginFailed(loginError)

type permissionMode = ReadOnly | Standard
