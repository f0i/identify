import { canisterId, createActor } from "../declarations/backend";
import { AuthResponse } from "../declarations/backend/backend.did";

declare global {
  interface Window {
    google: any;
  }
}

var authRequest: any = null;
var origin: string | null = null;

export function initICgsi(clientID: string) {
  const status = document.getElementById("login-status")!;
  const icgsi = document.getElementById("icgsi")!;
  icgsi.style.display = "block";
  status.innerText = "Waiting for session key...";

  window.addEventListener("message", (event) => {
    if (
      event.source === window.opener &&
      event.data.kind === "authorize-client"
    ) {
      console.log("setting data", event.data);
      authRequest = event.data;
      origin = event.origin;
      const appOrigin = document.getElementById("app-origin")!;
      appOrigin.innerText = origin;
      const nonce = uint8ArrayToHex(authRequest.sessionPublicKey);
      initGsi(clientID, nonce);
      status.innerText = "";
    } else {
      console.log("unhandled message (ignore)", event);
    }
  });

  const msg = { kind: "authorize-ready" };
  window.opener.postMessage(msg, "*");

  const appOrigin = document.getElementById("app-origin")!;
  appOrigin.innerText = "-";
}

async function initGsi(clientId: string, nonce: string) {
  window.google.accounts.id.initialize({
    client_id: clientId,
    callback: handleCredentialResponse,
    nonce: nonce,
  });

  window.google.accounts.id.renderButton(
    document.getElementById("icgsi-google-btn")!,
    { theme: "outline", size: "large" },
  );

  window.google.accounts.id.prompt();
}

async function handleCredentialResponse(response: any) {
  const status = document.getElementById("login-status")!;
  try {
    const idToken = response.credential;
    console.log(response);

    // decode payload
    const payload = JSON.parse(atob(idToken.split(".")[1]));

    const isDev = process.env.DFX_NETWORK !== "ic";
    const host = isDev ? "http://localhost:4943" : "https://icp-api.io";

    const backend = createActor(canisterId, { agentOptions: { host } });

    status.innerText = "Google sign in succeeded. Authorizing client...";

    if (!origin) {
      throw "Could not determine app origin.";
    }

    console.log("payload:", payload, payload.sub);
    let prepRes = await backend.prepareDelegation(
      idToken,
      origin,
      authRequest.sessionPublicKey,
      authRequest.maxTimeToLive,
    );
    if ("ok" in prepRes) {
      console.log("prepareDelegation response:", prepRes.ok);
    } else {
      throw prepRes.err;
    }
    status.innerText = "Google sign in succeeded. Get client authorization...";

    if (!authRequest?.sessionPublicKey)
      throw "Sign in failed: Session key was not set.";
    console.log("authRequest data from auth-client:", authRequest);

    let authRes = await backend.getDelegation(
      idToken,
      origin,
      authRequest.sessionPublicKey,
      prepRes.ok.expireAt,
    );

    console.log("getDelegation response:", authRes);
    if ("ok" in authRes) {
      console.log("authRes", authRes.ok);
      status.innerText = "Login completed";
      debugger;
      // send response; window will be closed by opener
      const msg = unwrapTargets(authRes.ok.auth);
      window.opener.postMessage(msg, "*");
    } else {
      throw "Could not sign in: " + authRes.err;
    }
  } catch (err: any) {
    status.innerText = err.toString();
  }
}

export interface AuthResponseUnwrapped {
  kind: string;
  delegations: Array<DelegationUnwrapped>;
  authnMethod: string;
  userPublicKey: Uint8Array | number[];
}
export interface DelegationUnwrapped {
  signature: Uint8Array | number[];
  delegation: {
    pubkey: Uint8Array | number[];
    targets?: Array<any>;
    expiration: bigint;
  };
}
function unwrapTargets(authRes: AuthResponse): AuthResponseUnwrapped {
  return {
    ...authRes,
    delegations: authRes.delegations.map((d): DelegationUnwrapped => {
      if (d.delegation.targets.length > 0) return d;
      const { targets: _, ...delegation } = d.delegation;
      return { ...d, delegation };
    }),
  };
}

function uint8ArrayToHex(array: Uint8Array): string {
  return Array.from(array)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
