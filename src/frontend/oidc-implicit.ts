import { backend } from "../declarations/backend";
import { OIDCConfig } from "./auth-config";
import { StatusUpdate } from "./identify/icrc";

export type OidcAuthData =
  | { token_type: "id_token"; id_token: string }
  | { token_type: "code"; code: string };

/**
 * Check if FedCM is available and should be used
 */
export const hasFedCM = (config: OIDCConfig): boolean => {
  // Config without fedCMConfigUrl
  if (!config.fedCM_config_url) return false;

  // No FedCM support
  if (!("IdentityCredential" in window)) return false;

  // Unsupported implementations
  if (/SamsungBrowser/i.test(navigator.userAgent)) return false;

  if (localStorage.getItem("disable-fedcm") === "true") return false;

  return true;
};

/**
 * Get stored login hint for a provider
 */
const getLoginHint = (providerName: string): string | undefined => {
  const key = `fedcm-login-hint-${providerName.toLowerCase()}`;
  return localStorage.getItem(key) || undefined;
};

/**
 * Store login hint for future use
 */
const storeLoginHint = (providerName: string, hint: string): void => {
  const key = `fedcm-login-hint-${providerName.toLowerCase()}`;
  localStorage.setItem(key, hint);
};

/**
 * Extract login hint from ID token
 */
const extractLoginHintFromToken = (idToken: string): string | undefined => {
  try {
    const payload = JSON.parse(atob(idToken.split(".")[1]));
    // Prefer email, fall back to sub (subject identifier)
    return payload.email || payload.preferred_username || payload.sub;
  } catch (e) {
    console.warn("Failed to extract login hint from token:", e);
    return undefined;
  }
};

/**
 * Request authentication using FedCM
 */
const requestFedCM = async (
  config: OIDCConfig,
  nonce: string,
  mediation: CredentialMediationRequirement,
): Promise<string> => {
  if (!config.fedCM_config_url)
    throw "Invalid configuration. FedCM config url not set.";

  const loginHint = getLoginHint(config.name);

  const identityCredential = await navigator.credentials.get({
    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
    // @ts-ignore
    identity: {
      context: "use",
      providers: [
        {
          configURL: config.fedCM_config_url,
          clientId: config.client_id,
          nonce: nonce,
          loginHint: loginHint,
        },
      ],
      mode: "active",
    },
    mediation: mediation,
  });
  console.log("FedCM returned credentials:", identityCredential);

  if (
    identityCredential?.type !== "identity" ||
    !("token" in identityCredential) ||
    typeof identityCredential.token !== "string"
  ) {
    // This should be unreachable in FedCM spec compliant browsers
    throw new Error("Invalid credential received from FedCM API");
  }

  // Store login hint for next time
  const hint = extractLoginHintFromToken(identityCredential.token);
  if (hint) {
    storeLoginHint(config.name, hint);
  }

  return identityCredential.token;
};

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

  const signinWithPopup = async (): Promise<OidcAuthData> => {
    popup = window.open(authUrl.href, "_blank", "width=500,height=600");
    if (!popup) throw new Error("Could not open popup");

    return new Promise<OidcAuthData>((resolve, reject) => {
      const messageListener = (event: MessageEvent) => {
        if (event.source === popup) {
          window.removeEventListener("message", messageListener);
          popup?.close();

          if (event.data.type === "oidc_auth_success") {
            if (event.data.state !== state) {
              return reject(new Error("Invalid state"));
            } else {
              return resolve({
                token_type: "id_token",
                id_token: event.data.id_token,
              });
            }
          } else if (event.data.type === "oidc_auth_code") {
            if (event.data.state !== state) {
              return reject(new Error("Invalid state"));
            } else {
              return resolve({ token_type: "code", code: event.data.code });
            }
          } else if (event.data.type === "oidc_auth_error") {
            return reject(new Error(event.data.error));
          }
        }
      };

      window.addEventListener("message", messageListener);
    });
  };

  const signin = async (): Promise<OidcAuthData> => {
    // Try FedCM first if available
    if (hasFedCM(config)) {
      try {
        const token = await requestFedCM(config, nonce, "required");
        return { token_type: "id_token", id_token: token };
      } catch (e) {
        console.log("FedCM failed, falling back to popup:", e);
        // Fall through to popup flow
      }
    }

    // Use popup flow
    return await signinWithPopup();
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
