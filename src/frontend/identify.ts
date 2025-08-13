import { setText, showElement } from "./identify/dom";
import { uint8ArrayToHex } from "./identify/utils";
import { getDelegation, ProviderKey, getProviderName } from "./identify/delegation";
import { Context, DEFAULT_CONTEXT, handleJSONRPC } from "./identify/icrc";
import { initGsi } from "./identify/google";
import { Principal } from "@dfinity/principal";
import {
  AuthConfig,
  getAuth0Config,
  getGoogleConfig,
  getZitadelConfig,
  GoogleConfig,
} from "./auth-config";
import { DOM_IDS } from "./dom-config";
import { initAuth0 } from "./auth0";
import { initZitadel } from "./zitadel";

declare global {
  interface Window {
    google: any;
  }
}

const responder = (msg: any) => {
  window.opener.postMessage(msg, "*");
};

// DOM manipulation
const setOriginText = (origin: string) => setText(DOM_IDS.appOrigin, origin);
const setTargetsText = (targets: string) => {
  showElement(DOM_IDS.targetsWrapper, targets.length > 0);
  setText(DOM_IDS.targets, targets);
};
const setStatusText = (status: string) => setText(DOM_IDS.loginStatus, status);

let context: Context = DEFAULT_CONTEXT;

export function initIdentify(provider: ProviderKey, config: AuthConfig) {
  showElement("identify", true);
  const signInButtonContainer = document.getElementById(DOM_IDS.singinBtn);
  if (signInButtonContainer) {
    const actualButton = signInButtonContainer.querySelector('button');
    if (actualButton) {
      actualButton.innerText = `Sign in with ${getProviderName(provider)}`;
    }
  }
  console.log("Waiting for message from opener");
  setStatusText("Connecting to application...");
  let init = true;

  context.getAuthToken = async (nonce: string) => {
    switch (provider) {
      case "google":
        return await initGsi(
          getGoogleConfig(config),
          nonce,
          DOM_IDS.singinBtn,
          true,
        );
      case "auth0":
        return await initAuth0(
          getAuth0Config(config),
          nonce,
          DOM_IDS.singinBtn,
          false,
        );
      case "zitadel":
        return await initZitadel(
          getZitadelConfig(config),
          nonce,
          DOM_IDS.singinBtn,
          false,
        );
      default:
        throw "Invalid provider " + provider.toString();
    }
  };
  context.provider = provider;
  context.authConfig = config;

  context.statusCallback = setStatusText;
  context.targetsCallback = setTargetsText;
  context.originCallback = setOriginText;
  console.log("context:", context);

  window.addEventListener("message", async (event) => {
    if (event.source === window.opener) {
      origin = event.origin;
      setOriginText(origin);
      context.origin = origin;

      // first message from opener
      if (init) {
        console.log("Received message from opener:", event);
        setStatusText("Connected to " + origin);
        init = false;
      }

      if (event.data.jsonrpc === "2.0") {
        //
        // Handle JSON-RPC requests according to ICRC-25
        //
        await handleJSONRPC(event.data, responder, context);
      } else if (event.data.kind === "authorize-client") {
        //
        // Handle authorize-client request according to the II-Spec
        //
        await handleAuthorizeClient(event.origin, event.data, context);
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
  authRequest: {
    sessionPublicKey: Uint8Array;
    maxTimeToLive: bigint;
    targets?: Principal[];
  },
  context: Context,
): Promise<void> => {
  try {
    if (!origin) {
      throw "Could not determine app origin.";
    }
    context.originCallback(origin);
    context.targetsCallback("");
    context.targetsCallback(authRequest.targets?.slice()?.join(",\n") || "");
    const nonce = uint8ArrayToHex(authRequest.sessionPublicKey);
    setStatusText("");
    // Request Google Sign-In and get the JWT token
    const auth = await context.getAuthToken(nonce);

    // Get delegation from backend using the JWT token
    const msg = await getDelegation(
      context.provider,
      auth,
      origin,
      authRequest.sessionPublicKey,
      authRequest.maxTimeToLive,
      authRequest.targets,
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
