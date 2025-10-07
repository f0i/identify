import {
  UserManager,
  UserManagerSettings,
  WebStorageStateStore,
} from "oidc-client-ts";
import { OIDCConfig } from "./auth-config";
import { StatusUpdate } from "./identify/icrc";

export async function initOIDC(
  config: OIDCConfig,
  nonce: string,
  buttonId: string,
  autoSignIn: boolean = false,
  statusCallback: (update: StatusUpdate) => void,
): Promise<string> {
  const options: UserManagerSettings = {
    authority: config.authority,
    client_id: config.client_id,
    response_type: config.response_type,
    scope: config.scope,
    redirect_uri: document.location.origin + "/callback.html",
    loadUserInfo: false,
    userStore: new WebStorageStateStore({ store: window.localStorage }),
  };
  console.log("OIDC options", options);
  const userManager = new UserManager(options);

  async function signin() {
    if (hasFedCM(config)) {
      return await requestFedCM(config, nonce, "required");
    }
    const user = await userManager.signinPopup({ nonce });
    console.log("Access token:", user.access_token);
    console.log("ID token:", user.id_token);
    if (!user.id_token) {
      throw "Failed to sing in with OIDC: missing ID Token";
    }
    return user.id_token;
  }

  const attachButton = (): Promise<string> => {
    const login = document.getElementById(buttonId);
    if (login) {
      console.log("Adding listner to login button", login);
      return new Promise((resolve, reject) => {
        login.addEventListener("click", () => signin().then(resolve, reject));
      });
    } else {
      throw "Login button not found";
    }
  };

  if (autoSignIn) {
    try {
      return await signin();
    } catch (e) {
      // TODO: check if error message should be shown
      statusCallback({ status: "error", message: `${e}` });
    }
  }
  while (true) {
    try {
      statusCallback({ status: "ready", message: "" });
      return await attachButton();
    } catch (e) {
      // TODO: check if error is recoverable
      throw e;
    }
  }
}

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
