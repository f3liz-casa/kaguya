// SPDX-License-Identifier: MPL-2.0

@jsx.component
let make = () => {
  let (status, setStatus) = PreactHooks.useState(() => "checking")
  let (errorMessage, setErrorMessage) = PreactHooks.useState(() => None)

  PreactHooks.useEffect0(() => {
    let isMounted = ref(true)

    let checkAuth = async () => {
      try {
        if isMounted.contents {

          let params = KaguyaNetwork.searchParams()->Obj.magic
          let errorParam: option<string> = params->URLSearchParams.get("error")

          switch errorParam {
          | Some(error) => {
              Console.error2("OAuthCallbackPage: Authorization error:", error)
              if isMounted.contents {
                setStatus(_ => "error")
                setErrorMessage(_ => Some(error))
              }
            }
          | None => {
              let result = await AuthManager.checkOAuth2()

              switch result {
              | Ok() => {
                  if isMounted.contents {
                    setStatus(_ => "success")
                    KaguyaNetwork.navigateTo("/")
                  }
                }
              | Error(err) => {
                  Console.error2("OAuthCallbackPage: OAuth2 check failed:", err)
                  let errorMsg = switch err {
                  | AuthTypes.InvalidCredentials => "認証情報が無効です"
                  | AuthTypes.NetworkError(msg) => msg
                  | AuthTypes.UnknownError(msg) => msg
                  }
                  if isMounted.contents {
                    setStatus(_ => "error")
                    setErrorMessage(_ => Some(errorMsg))
                  }
                }
              }
            }
          }
        }
      } catch {
      | exn => {
          Console.error("OAuthCallbackPage: Exception in checkAuth")
          Console.error(exn)
          if isMounted.contents {
            setStatus(_ => "error")
            let msg = switch exn->JsExn.fromException {
            | Some(jsExn) => JsExn.message(jsExn)->Option.getOr("不明なエラー")
            | None => "不明なエラー"
            }
            setErrorMessage(_ => Some(msg))
          }
        }
      }
    }

    let _ = checkAuth()
    Some(() => { isMounted.contents = false })
  })

  <main className="container login-page">
    <article className="login-card">
      <header>
        <h1 className="login-title"> {Preact.string("かぐや")} </h1>
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
            <a href="/"> {Preact.string("ログインページへ戻る")} </a>
          </p>
        </div>
      | _ => Preact.null
      }}
    </article>
  </main>
}
