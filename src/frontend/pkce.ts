import { AuthConfig, getPKCEConfig } from "./auth-config";
import { StatusUpdate } from "./identify/icrc";

export type PkceAuthData = { code: string; verifier: string; state?: string };

export async function generateChallenge(
  sessionKey: Uint8Array,
): Promise<{ verifier: string; challenge: string }> {
  // add random string to the session key.
  // The total length of the verifier must not be more than 128 chars
  const verifier = await sha256Hex(sessionKey);

  console.log(
    "Using verifier:",
    verifier,
    "and code:",
    await generateCodeChallenge(verifier),
  );
  return {
    verifier,
    challenge: await generateCodeChallenge(verifier),
  };
}

async function generateCodeChallenge(code_verifier: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(code_verifier);
  const hashBuffer = await window.crypto.subtle.digest("SHA-256", data);
  return base64urlencode(hashBuffer);
}

function base64urlencode(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let str = "";
  for (let i = 0; i < bytes.length; i++) {
    str += String.fromCharCode(bytes[i]);
  }
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

async function sha256Hex(input: Uint8Array): Promise<string> {
  // Compute SHA-256 hash
  const hashBuffer = await crypto.subtle.digest("SHA-256", input);
  // Convert buffer to byte array
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  // Convert each byte to hex and join
  const hashHex = hashArray
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return hashHex;
}

export async function initPkce(
  config: AuthConfig,
  code_challenge: string,
  verifier: string,
  buttonId: string,
  autoSignIn: boolean = true,
  statusCallback: (update: StatusUpdate) => void,
): Promise<PkceAuthData> {
  const pkceConfig = getPKCEConfig(config);

  // Redirect to the authorization endpoint in a popup
  const state = Array.from(
    window.crypto.getRandomValues(new Uint8Array(16)),
    (b) => b.toString(16).padStart(2, "0"),
  ).join("");
  let redirect = document.location.origin + "/pkce-callback.html";
  const authUrl =
    `${pkceConfig.authorization_url}?` +
    `client_id=${pkceConfig.client_id}&` +
    `redirect_uri=${encodeURIComponent(redirect)}&` +
    `response_type=code&` +
    `scope=${encodeURIComponent(pkceConfig.scope)}&` +
    `code_challenge=${encodeURIComponent(code_challenge)}&` +
    `code_challenge_method=S256&` +
    `state=${encodeURIComponent(state)}`;

  let popup: any;
  const signin = async (): Promise<PkceAuthData> => {
    console.log("PKCE: signin called");
    popup = window.open(authUrl, "_blank", "width=500,height=600");
    if (!popup) {
      throw "Could not open popup";
    }

    return new Promise(async (resolve, reject) => {
      const messageListener = (event: MessageEvent) => {
        if (event.source === popup) {
          window.removeEventListener("message", messageListener);
          if (event.data.type === "pkce_auth_success") {
            // TODO: verify state matches
            resolve({
              code: event.data.code,
              state: event.data.state,
              verifier: verifier,
            });
          } else if (event.data.type === "pkce_auth_error") {
            reject(new Error(event.data.error));
          }
          popup.close();
        }
      };
      window.addEventListener("message", messageListener);
    });
  };

  const attachButton = (): Promise<PkceAuthData> => {
    const login = document.getElementById(buttonId);
    if (login) {
      console.log("Adding listner to login button", login);
      return new Promise(async (resolve, reject) => {
        login.addEventListener("click", () => signin().then(resolve, reject));
      });
    } else {
      console.error("Login button not found");
      return Promise.reject("Login button not found");
    }
  };

  if (autoSignIn) {
    statusCallback({ status: "signing-in", message: "" });
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
      statusCallback({ status: "error", message: `${e}` });
      throw e;
    }
  }
}
