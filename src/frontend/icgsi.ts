import { canisterId, createActor } from "../declarations/backend";
import { AuthResponse, PrepRes } from "../declarations/backend/backend.did";

declare global {
  interface Window {
    google: any;
  }
}

var authRequest: any = null;

export function initICgsi(clientID: string) {
  const icgsi = document.getElementById("icgsi")!;
  icgsi.style.display = "block";

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

  const msg = { kind: "authorize-ready" };
  window.opener.postMessage(msg, "*");

  const appOrigin = document.getElementById("app-origin")!;
  appOrigin.innerText = referrer.origin;
}

async function initGsi(clientId: string) {
  window.google.accounts.id.initialize({
    client_id: clientId,
    callback: handleCredentialResponse,
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
    const referrer = new URL(document.referrer);

    console.log("payload:", payload, payload.sub);
    let prepRes = await backend.prepareDelegation(
      payload.sub,
      referrer.origin,
      123454321,
    );
    if ("ok" in prepRes) {
      if (prepRes.ok.register) {
        status.innerText = "Google sign in succeeded. Generate new identity...";
        // Small delay to make be able to read the above message
        // and to make sure all nodes receive state with new keys before next query call (just in case; unlikely to be actually needed)
        await new Promise((resolve) => setTimeout(resolve, 300));
      }
    } else {
      throw prepRes.err;
    }
    console.log("prepareDelegation response:", prepRes);
    status.innerText = "Google sign in succeeded. Get client authorization...";

    if (!authRequest?.sessionPublicKey)
      throw "Sign in failed: Session key was not set.";

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
