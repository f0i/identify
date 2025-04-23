import { canisterId, createActor } from "../declarations/backend";
import { AuthResponse, Delegation } from "../declarations/backend/backend.did";
import { Principal } from "@dfinity/principal";

declare global {
  interface Window {
    google: any;
  }
}

const DEFAULT_TTL = 30n * 60n * 1_000_000_000n;

var authRequest: {
  sessionPublicKey: Uint8Array;
  maxTimeToLive: bigint;
} | null = null;
var origin: string | null = null;
var mode: "authorize-client" | "jsonrpc";

const responder = (msg: any) => {
  window.opener.postMessage(msg, "*");
};

export function initICgsi(clientID: string) {
  const status = document.getElementById("login-status")!;
  const icgsi = document.getElementById("icgsi")!;
  icgsi.style.display = "block";
  status.innerText = "Waiting for session key...";

  window.addEventListener("message", async (event) => {
    if (
      event.source === window.opener &&
      event.data.kind === "authorize-client"
    ) {
      mode = "authorize-client";
      console.log("setting data", event.data);
      authRequest = event.data;
      if (!authRequest) {
        console.error("missing auth data");
        return;
      }
      origin = event.origin;
      const appOrigin = document.getElementById("app-origin")!;
      appOrigin.innerText = origin;
      const nonce = uint8ArrayToHex(authRequest.sessionPublicKey);
      status.innerText = "";
      const auth = await initGsi(clientID, nonce);
      const msg = await handleCredentialResponse(
        auth,
        authRequest.sessionPublicKey,
        authRequest.maxTimeToLive,
      );
      responder(msg);
    } else if (event.source === window.opener && event.data.jsonrpc === "2.0") {
      origin = event.origin;
      const appOrigin = document.getElementById("app-origin")!;
      appOrigin.innerText = origin;
      await handleJSONRPC(event.data, clientID);
    } else {
      console.log("unhandled message (ignore)", event);
    }
  });

  responder({ kind: "authorize-ready" });

  const appOrigin = document.getElementById("app-origin")!;
  appOrigin.innerText = "-";
}

async function initGsi(
  clientId: string,
  nonce: string,
): Promise<{ credential: string }> {
  return new Promise((resolve, _reject) => {
    window.google.accounts.id.initialize({
      client_id: clientId,
      callback: resolve,
      nonce: nonce,
    });

    window.google.accounts.id.renderButton(
      document.getElementById("icgsi-google-btn")!,
      { theme: "outline", size: "large" },
    );

    window.google.accounts.id.prompt();
  });
}

async function handleCredentialResponse(
  response: { credential: string },
  sessionPublicKey: Uint8Array,
  maxTimeToLive: bigint,
  targets?: Principal[],
): Promise<AuthResponseUnwrapped> {
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
      sessionPublicKey,
      maxTimeToLive,
      wrapOpt(targets),
    );
    if ("ok" in prepRes) {
      console.log("prepareDelegation response:", prepRes.ok);
    } else {
      throw prepRes.err;
    }
    status.innerText = "Google sign in succeeded. Get client authorization...";

    let authRes = await backend.getDelegation(
      idToken,
      origin,
      sessionPublicKey,
      prepRes.ok.expireAt,
      wrapOpt(targets),
    );

    console.log("getDelegation response:", authRes);
    if ("ok" in authRes) {
      console.log("authRes", authRes.ok);
      status.innerText = "Login completed";
      debugger;
      // send response; window will be closed by opener
      const msg = unwrapTargets(authRes.ok.auth);
      return msg;
    } else {
      throw "Could not sign in: " + authRes.err;
    }
  } catch (err: any) {
    status.innerText = err.toString();
    throw err;
  }
}

type DelegationParams = {
  publicKey: string;
  targets?: string[];
  maxTimeToLive?: string;
};

const handleJSONRPC = async (
  data: {
    method: string;
    id: string;
    params?: DelegationParams;
  },
  clientID: string,
) => {
  switch (data.method) {
    case "icrc29_status":
      const ready = { jsonrpc: "2.0", id: data.id, result: "ready" };
      responder(ready);
      break;

    case "icrc34_delegation":
      if (!data.params) {
        console.error("missing params in icrc34_delegation");
        return;
      }
      mode = "jsonrpc";
      const publicKey = base64decode(data.params?.publicKey);
      const maxTimeToLive = BigInt(data.params.maxTimeToLive || DEFAULT_TTL);
      const targets = data.params.targets?.map((p) => Principal.fromText(p));
      const nonce = uint8ArrayToHex(publicKey);
      const status = document.getElementById("login-status")!;
      status.innerText = "";
      const auth = await initGsi(clientID, nonce);
      const msg = await handleCredentialResponse(
        auth,
        publicKey,
        maxTimeToLive,
        targets,
      );

      const jsonrpcRes = {
        jsonrpc: "2.0",
        id: data.id,
        result: {
          publicKey: base64encode(msg.userPublicKey),
          signerDelegation: msg.delegations.map(delegationToJsonRPC),
        },
      };
      console.log("jsonrpcRes", jsonrpcRes);
      responder(jsonrpcRes);
      break;
    default: {
      console.warn("unhandled JSONRPC call", data);
    }
  }
};

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

function wrapOpt(val?: any): [] | [any] {
  if (val === undefined) return [];
  return [val];
}

function uint8ArrayToHex(array: Uint8Array): string {
  return Array.from(array)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function base64decode(base64: string): Uint8Array {
  const bin = atob(base64);
  const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
  return bytes;
}

function base64encode(bytes: Uint8Array | number[]): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

function delegationToJsonRPC(delegation: DelegationUnwrapped): {
  delegation: {
    pubkey: string;
    expiration: string;
    targets?: string[];
  };
  signature: string;
} {
  return {
    delegation: {
      pubkey: base64encode(delegation.delegation.pubkey),
      targets: delegation.delegation.targets?.map((p) => p.toString()), // TODO: check if toString is doing the correct encoding
      expiration: delegation.delegation.expiration.toString(),
    },
    signature: base64encode(delegation.signature),
  };
}
