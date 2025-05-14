import { canisterId, createActor } from "../declarations/backend";
import {
  AuthResponse,
  Delegation,
  init,
} from "../declarations/backend/backend.did";
import { Principal } from "@dfinity/principal";
import type {
  HttpAgent,
  ActorSubclass,
  HttpAgentOptions,
  ActorConfig,
  Agent,
} from "@dfinity/agent";
import { setText } from "./identify/dom";
import { AuthResponseUnwrapped, uint8ArrayToHex } from "./identify/utils";
import { getDelegation } from "./identify/delegation";
import { Context, handleJSONRPC } from "./identify/icrc";
import { initGsi } from "./identify/google";

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

// DOM mainpulation
const setOriginText = (origin: string) => setText("app-origin", origin);
const setTargetsText = (targets: string) => setText("app-targets", targets);
const setStatusText = (status: string) => setText("login-status", status);

let context: Context = {};
function setContext(newContext: Context): void {
  context = newContext;
}

export function initICgsi(clientID: string) {
  const icgsi = document.getElementById("icgsi")!;
  icgsi.style.display = "block";
  setStatusText("Waiting for session key...");

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
      setOriginText(origin);
      setTargetsText("Unrestricted");
      const nonce = uint8ArrayToHex(authRequest.sessionPublicKey);
      setStatusText("");
      const auth = await initGsi(clientID, nonce);
      const msg = await handleCredentialResponse(
        auth,
        authRequest.sessionPublicKey,
        authRequest.maxTimeToLive,
      );
      responder(msg);
    } else if (event.source === window.opener && event.data.jsonrpc === "2.0") {
      origin = event.origin;
      setOriginText(origin);
      await handleJSONRPC(
        event.data,
        responder,
        setStatusText,
        setTargetsText,
        async (nonce: string) => {
          let auth = await initGsi(clientID, nonce);
          return auth.credential;
        },
        context,
        setContext,
      );
    } else {
      // Messages are probably not relevant, e.g. from browser plugins
      console.log("unhandled message (ignore)", event);
    }
  });

  responder({ kind: "authorize-ready" });

  setOriginText("-");
}

let authResponse: { credential: string } | null = null;
let authCallback: (response: { credential: string }) => void;
async function getAuthToken() {
  if (authResponse) {
    return authResponse.credential;
  } else {
    return new Promise((resolve) => {
      authCallback = resolve;
    });
  }
}

async function handleCredentialResponse(
  response: { credential: string },
  sessionPublicKey: Uint8Array,
  maxTimeToLive: bigint,
  targets?: Principal[],
): Promise<AuthResponseUnwrapped> {
  try {
    if (!origin) {
      throw "Could not determine app origin.";
    }

    return await getDelegation(
      response.credential,
      origin!,
      sessionPublicKey,
      maxTimeToLive,
      targets,
      setStatusText,
    );

    // decode payload
  } catch (err: any) {
    setStatusText(err.toString());
    throw err;
  }
}
