import { setText } from "./identify/dom";
import { uint8ArrayToHex } from "./identify/utils";
import { getDelegation } from "./identify/delegation";
import { Context, DEFAULT_CONTEXT, handleJSONRPC } from "./identify/icrc";
import { initGsi } from "./identify/google";

declare global {
  interface Window {
    google: any;
  }
}

const responder = (msg: any) => {
  window.opener.postMessage(msg, "*");
};

// DOM manipulation
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
  context.statusCallback = setStatusText;
  context.targetsCallback = setTargetsText;
  context.originCallback = setOriginText;
  console.log("context:", context);

  window.addEventListener("message", async (event) => {
    if (event.source === window.opener) {
      origin = event.origin;
      setOriginText(origin);
      context.origin = origin;

      if (event.data.jsonrpc === "2.0") {
        //
        // Handle JSON-RPC requests according to ICRC-25
        //
        await handleJSONRPC(event.data, responder, context);
      } else if (event.data.kind === "authorize-client") {
        //
        // Handle authorize-client request according to the II-Spec
        //
        await handleAuthorizeClient(
          event.origin,
          event.data,
          clientID,
          context,
        );
      } else {
        // Other messages are probably not relevant, e.g. from browser plugins
        console.log("unhandled message (ignore)", event);
      }
    }
  });

  // At this point, we don't know if the opener uses the II workflow or ICRC-25.
  // So we just send the "authorize-ready" message according to the II-Spec.
  // If the opener uses ICRC-25, it will ignore this message.
  responder({ kind: "authorize-ready" });

  // Origin is not known yet, so we set it to a placeholder
  setOriginText("-");
}

/// Handle "authorize-client" request according to the II-Spec.
const handleAuthorizeClient = async (
  origin: string | null,
  authRequest: { sessionPublicKey: Uint8Array; maxTimeToLive: bigint },
  clientID: string,
  context: Context,
): Promise<void> => {
  try {
    if (!origin) {
      throw "Could not determine app origin.";
    }
    context.originCallback(origin);
    context.targetsCallback("Unrestricted");
    const nonce = uint8ArrayToHex(authRequest.sessionPublicKey);
    setStatusText("");
    // Request Google Sign-In and get the JWT token
    const auth = await initGsi(clientID, nonce);

    // Get delegation from backend using the JWT token
    const msg = await getDelegation(
      auth.credential,
      origin,
      authRequest.sessionPublicKey,
      authRequest.maxTimeToLive,
      undefined,
      setStatusText,
    );

    // send response; window will be closed by opener
    responder(msg);
  } catch (err: any) {
    console.error("Error handling authorize-client request:", err);
    setStatusText(err.toString());
    responder({ kind: "authorize-error", error: err.toString() });
  }
};
