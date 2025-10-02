import { backend } from "../declarations/backend";
import { OIDCConfig } from "./auth-config";
import { StatusUpdate } from "./identify/icrc";

export type OidcAuthData = string;

/**
 * Initialize OIDC implicit flow in a popup.
 * @param config Auth configuration
 * @param buttonId DOM id of the login button
 * @param autoSignIn automatically trigger signin on init
 * @param statusCallback callback to update status messages
 */
export async function initOIDC(
  config: OIDCConfig,
  nonce: string,
  buttonId: string,
  autoSignIn: boolean = true,
  statusCallback: (update: StatusUpdate) => void,
): Promise<OidcAuthData> {
  const state = Array.from(
    window.crypto.getRandomValues(new Uint8Array(16)),
    (b) => b.toString(16).padStart(2, "0"),
  ).join("");

  const redirect = document.location.origin + "/oidc-callback.html";
  const authUrl = new URL(config.authorization_url);
  authUrl.search = new URLSearchParams({
    client_id: config.client_id,
    redirect_uri: redirect,
    response_type: config.response_type,
    scope: config.scope,
    state,
    nonce,
  }).toString();

  let popup: Window | null = null;

  const signin = async (): Promise<OidcAuthData> => {
    popup = window.open(authUrl.href, "_blank", "width=500,height=600");
    if (!popup) throw new Error("Could not open popup");

    return new Promise((resolve, reject) => {
      const messageListener = (event: MessageEvent) => {
        if (event.source === popup) {
          window.removeEventListener("message", messageListener);
          popup?.close();

          if (event.data.type === "oidc_auth_success") {
            if (event.data.state !== state) {
              reject(new Error("Invalid state"));
              return;
            }
            resolve(event.data.id_token);
          } else if (event.data.type === "oidc_auth_code") {
            backend
              .exchangeToken(config.name.toLowerCase(), event.data.code, [])
              .then(
                (res) => {
                  if ("ok" in res) {
                    const data = res.ok;
                    resolve(JSON.parse(data).id_token);
                  } else {
                    reject("Failed to get ID Token: " + res.err);
                  }
                },
                (err) => {
                  reject("Failed to get ID Token: " + err);
                },
              );
            if (event.data.state !== state) {
              reject(new Error("Invalid state"));
              return;
            }
          } else if (event.data.type === "oidc_auth_error") {
            reject(new Error(event.data.error));
          }
        }
      };

      window.addEventListener("message", messageListener);
    });
  };

  const attachButton = (): Promise<OidcAuthData> => {
    const loginBtn = document.getElementById(buttonId);
    if (!loginBtn) return Promise.reject("Login button not found");

    return new Promise((resolve, reject) => {
      loginBtn.addEventListener("click", () => signin().then(resolve, reject));
    });
  };

  if (autoSignIn) {
    statusCallback({ status: "signing-in", message: "" });
    try {
      return await signin();
    } catch (e) {
      statusCallback({ status: "error", message: `${e}` });
    }
  }

  statusCallback({ status: "ready", message: "" });
  return await attachButton();
}
