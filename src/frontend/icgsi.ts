import { Principal } from "@dfinity/principal";
import { setText } from "./identify/dom";
import { AuthResponseUnwrapped, uint8ArrayToHex } from "./identify/utils";
import { getDelegation } from "./identify/delegation";
import { Context, DEFAULT_CONTEXT, handleJSONRPC } from "./identify/icrc";
import { initGsi } from "./identify/google";

declare global {
  interface Window {
    google: any;
  }
}

var authRequest: {
  sessionPublicKey: Uint8Array;
  maxTimeToLive: bigint;
} | null = null;
var origin: string | null = null;

const responder = (msg: any) => {
  window.opener.postMessage(msg, "*");
};

// DOM mainpulation
const setOriginText = (origin: string) => setText("app-origin", origin);
const setTargetsText = (targets: string) => setText("app-targets", targets);
const setStatusText = (status: string) => setText("login-status", status);

let context: Context = DEFAULT_CONTEXT;

export function initICgsi(clientID: string) {
  const icgsi = document.getElementById("icgsi")!;
  icgsi.style.display = "block";
  setStatusText("Waiting for session key...");

  context.getAuthToken = async (nonce: string) => {
    let auth = await initGsi(clientID, nonce);
    return auth.credential;
  };
  context.gsiClientID = clientID;
  console.log("context:", context);

  window.addEventListener("message", async (event) => {
    if (
      event.source === window.opener &&
      event.data.kind === "authorize-client"
    ) {
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
      // send response; window will be closed by opener
      responder(msg);
    } else if (event.source === window.opener && event.data.jsonrpc === "2.0") {
      origin = event.origin;
      setOriginText(origin);
      context.origin = origin;

      await handleJSONRPC(event.data, responder, context);
    } else {
      // Other messages are probably not relevant, e.g. from browser plugins
      console.log("unhandled message (ignore)", event);
    }
  });

  responder({ kind: "authorize-ready" });

  setOriginText("-");
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
