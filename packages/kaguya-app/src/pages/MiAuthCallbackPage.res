// SPDX-License-Identifier: MPL-2.0

let getSearchParams = (): URLSearchParams.t => {
  KaguyaNetwork.searchParams()->Obj.magic
}

@jsx.component
let make = () => {
  let (status, setStatus) = PreactHooks.useState(() => "checking")
  let (errorMessage, setErrorMessage) = PreactHooks.useState(() => None)
  let (retryCount, setRetryCount) = PreactHooks.useState(() => 0)
  let maxRetries = 10 // Retry up to 10 times with exponential backoff

  PreactHooks.useEffect1(() => {
    let isMounted = ref(true)
    let checkAuth = async () => {
      try {
        if !isMounted.contents {
          ()
        } else {

          let params = getSearchParams()
          let _sessionFromUrl = params->URLSearchParams.get("session")

          let result = await AuthManager.checkMiAuth()

          switch result {
          | Ok() => {
              setStatus(_ => "success")
              // Redirect immediately - don't wait for component state changes
              KaguyaNetwork.navigateTo("/")
            }
          | Error(err) => {
              Console.error2("MiAuthCallbackPage: MiAuth check failed:", err)

              // Extract error message
              let errorMsg = switch err {
              | AuthTypes.InvalidCredentials => "Invalid credentials"
              | AuthTypes.NetworkError(msg) => msg
              | AuthTypes.UnknownError(msg) => msg
              }

              let isPermanentError = String.includes(errorMsg, "Session information not found") || String.includes(errorMsg, "セッション")

              if isPermanentError {
                // Permanent error: redirect to login immediately with hard redirect
                setStatus(_ => "permanent_error")
                setErrorMessage(_ => Some(errorMsg))
                PreactSignals.setValue(AppState.authState, AuthTypes.LoginFailed(err))
                KaguyaNetwork.navigateTo("/")
              } else if retryCount < maxRetries {
                // Transient error: retry with exponential backoff
                // Delay: 1s, 2s, 4s, 8s, 16s, capped at 16s
                if isMounted.contents {
                  let rawDelay = 1000 * Int.fromFloat(Math.pow(2.0, ~exp=Int.toFloat(retryCount)))
                  let delay = rawDelay > 16000 ? 16000 : rawDelay
                  setStatus(_ => "checking")
                  let _ = SetTimeout.make(() => {
                    if isMounted.contents {
                      setRetryCount(prev => prev + 1)
                    }
                  }, delay)
                }
              } // Max retries exceeded: redirect to login with error
              else if isMounted.contents {
                setStatus(_ => "error")
                setErrorMessage(_ => Some(errorMsg))
                // Wait 2 seconds to show error, then redirect
                let _ = SetTimeout.make(() => {
                  KaguyaNetwork.navigateTo("/")
                }, 2000)
              }
            }
          }
        }
      } catch {
      | exn => {
          Console.error("MiAuthCallbackPage: Exception in checkAuth")
          Console.error(exn)
        }
      }
    }

    let _ = checkAuth()

    // Cleanup function: set isMounted to false when component unmounts
    Some(
      () => {
        isMounted.contents = false
      },
    )
  }, [retryCount])

  <main className="container">
    <article className="login-card">
      <header>
        <h1> {Preact.string("ログイン中...")} </h1>
      </header>
      {switch status {
      | "checking" =>
        <div className="loading-container">
          <p> {Preact.string("認証確認中...")} </p>
        </div>
      | "success" =>
        <div className="success-message">
          <div style={Style.make(~fontSize="2rem", ~marginBottom="0.5rem", ())}>
            {Preact.string("✓")}
          </div>
          <p> {Preact.string("ログイン成功！")} </p>
          <p
            style={Style.make(
              ~fontSize="0.875rem",
              ~fontWeight="400",
              ~marginTop="0.5rem",
              ~color="#158033",
              (),
            )}
          >
            {Preact.string("ホームへ移動中...")}
          </p>
        </div>
      | "permanent_error" =>
        <div className="error-message">
          <p> {Preact.string("セッションが期限切れか見つかりません。")} </p>
          <p style={Style.make(~fontSize="0.75rem", ~marginTop="0.5rem", ~color="#991b1b", ())}>
            {Preact.string("ログインページへ移動中...")}
          </p>
        </div>
      | "error" =>
        <div className="error-message">
          <p> {Preact.string("認証に失敗しました。")} </p>
          {switch errorMessage {
          | Some(msg) =>
            <details style={Style.make(~marginTop="0.5rem", ())}>
              <summary style={Style.make(~fontSize="0.75rem", ~color="#991b1b", ~cursor="pointer", ())}>
                {Preact.string("エラー詳細")}
              </summary>
              <pre
                style={Style.make(
                  ~fontSize="0.65rem",
                  ~marginTop="0.5rem",
                  ~padding="0.5rem",
                  ~backgroundColor="#fee2e2",
                  ~borderRadius="4px",
                  ~overflow="auto",
                  ~maxWidth="100%",
                  (),
                )}
              >
                {Preact.string(msg)}
              </pre>
            </details>
          | None => Preact.null
          }}
          <p style={Style.make(~fontSize="0.75rem", ~marginTop="0.5rem", ~color="#991b1b", ())}>
            {Preact.string("ログインページへ移動中...")}
          </p>
        </div>
      | _ => Preact.null
      }}
    </article>
  </main>
}
