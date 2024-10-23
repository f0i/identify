import { canisterId, createActor } from "../declarations/backend";
import { AuthResponse } from "../declarations/backend/backend.did";

declare global {
  interface Window {
    google: any;
  }
}

var authRequest: any = null;

export function initICgsi(clientID: string) {
  const referrer = new URL(document.referrer);
  initGsi(clientID);

  window.addEventListener("message", (event) => {
    if (
      event.origin === referrer.origin &&
      event.data.kind === "authorize-client"
    ) {
      console.log("setting data", event.data);
      authRequest = event.data;
    } else {
      console.log("unhandled message (ignore)", event);
    }
  });

  const status = document.getElementById("login-status")!;
  status.innerText = "Sign in to " + referrer.origin;

  const msg = { kind: "authorize-ready" };
  window.opener.postMessage(msg, "*");
}

async function initGsi(clientId: string) {
  window.google.accounts.id.initialize({
    client_id: clientId,
    callback: handleCredentialResponse,
  });

  window.google.accounts.id.renderButton(
    document.getElementById("icgsi") as HTMLElement,
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

    status.innerText = "Google login succeeded. Authorizing client...";
    const referrer = new URL(document.referrer);

    console.log("payload:", payload, payload.sub);
    let prepRes = backend.prepareDelegation(
      payload.sub,
      referrer.origin,
      123454321,
    );
    console.log("prepareDelegation response:", prepRes);
    status.innerText = "Google login succeeded. Get client authorization...";

    if (!authRequest?.sessionPublicKey) throw "Session key not set";

    let authRes = await backend.getDelegations(
      idToken,
      referrer.origin,
      authRequest.sessionPublicKey,
      authRequest.maxTimeToLive,
    );

    console.log("getDelegation response:", authRes);
    if ("ok" in authRes) {
      console.log("authRes", authRes.ok);
      status.innerText = "Login completed";
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
