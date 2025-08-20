import { setText, showElement } from "./identify/dom";
import { uint8ArrayToHex } from "./identify/utils";
import { ProviderKey, getProviderName } from "./identify/delegation";
import { Context, DEFAULT_CONTEXT, handleJSONRPC } from "./identify/icrc";
import { initGsi } from "./identify/google";
import { Principal } from "@dfinity/principal";
import {
  AuthConfig,
  getAuth0Config,
  getGoogleConfig,
  getZitadelConfig,
  getGithubConfig,
  getXConfig,
  getPKCEConfig,
} from "./auth-config";
import { DOM_IDS } from "./dom-config";
import { initAuth0 } from "./auth0";
import { generateChallenge, initPkce, PkceAuthData } from "./pkce";
import { initZitadel } from "./zitadel";
import { getDelegationJwt, getDelegationPkce } from "./identify/delegation";
import { StatusUpdate } from "./identify/icrc";

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

const setStatusText = (update: StatusUpdate) => {
  console.log(
    `Status changed to: ${update.status} with message: ${update.message} and error: ${update.error}`,
  );
  const statusEl = "login-status";
  const spinner = "spinner";
  const errorEl = "error";
  const signInBtn = "sign-in-btn";
  const cancelBtn = "cancel";

  setText(statusEl, update.message || ""); // Keep the message

  if (update.status === "loading") {
    showElement(statusEl, true); // Keep status message visible
    showElement(spinner, true); // Show spinner
    showElement(errorEl, false);
    showElement(signInBtn, false);
    showElement(cancelBtn, false);
  } else if (update.status === "ready") {
    showElement(statusEl, true); // Keep status message visible
    showElement(spinner, false); // Hide spinner
    showElement(errorEl, false);
    showElement(signInBtn, true);
    showElement(cancelBtn, false);
  } else if (update.status === "signing-in") {
    showElement(statusEl, true); // Keep status message visible
    showElement(spinner, true); // Show spinner
    showElement(errorEl, false);
    showElement(signInBtn, false);
    showElement(cancelBtn, true);
  } else if (update.status === "error") {
    showElement(statusEl, true); // Keep status message visible
    showElement(spinner, false); // Hide spinner
    showElement(errorEl, true);
    setText(errorEl, update.error || "Unknown error");
    showElement(signInBtn, true);
    showElement(cancelBtn, true);
  }
};

let context: Context = DEFAULT_CONTEXT;

export function initIdentify(provider: ProviderKey, config: AuthConfig) {
  showElement("identify", true);
  const signInButtonContainer = document.getElementById(DOM_IDS.singinBtn);
  if (signInButtonContainer) {
    const actualButton = signInButtonContainer.querySelector("button");
    if (actualButton) {
      actualButton.innerText = `Sign in with ${getProviderName(provider)}`;
    }
  }
  console.log("Waiting for message from opener");
  setStatusText({ status: "loading", message: "Connecting to application..." });
  let init = true;

  context.getJwtToken = async (nonce: string) => {
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
          true,
          context.statusCallback,
        );
      case "zitadel":
        return await initZitadel(
          getZitadelConfig(config),
          nonce,
          DOM_IDS.singinBtn,
          false,
          context.statusCallback,
        );
      default:
        throw "Invalid provider for JWT: " + provider.toString();
    }
  };

  context.getPkceAuthData = async (sessionKey: Uint8Array) => {
    const code = await generateChallenge(sessionKey);
    switch (provider) {
      case "github":
        return await initPkce(
          getGithubConfig(config),
          code.challenge,
          code.verifier,
          DOM_IDS.singinBtn,
          true,
          context.statusCallback,
        );
      case "x":
        return await initPkce(
          getXConfig(config),
          code.challenge,
          code.verifier,
          DOM_IDS.singinBtn,
          true,
          context.statusCallback,
        );
      default:
        throw "Invalid provider for PKCE: " + provider.toString();
    }
  };

  context.provider = provider;
  context.authConfig = config;

  context.statusCallback = (update) => setStatusText(update);
  context.targetsCallback = setTargetsText;
  context.originCallback = setOriginText;
  context.cancel = () => {
    window.close();
  };
  const cancelBtn = document.getElementById("cancel");
  cancelBtn?.addEventListener("click", () => context.cancel?.());

  console.log("context:", context);

  window.addEventListener("message", async (event) => {
    if (event.source === window.opener) {
      origin = event.origin;
      setOriginText(origin);
      context.origin = origin;

      // first message from opener
      if (init) {
        console.log("Received message from opener:", event);
        setStatusText({ status: "loading", message: "Connected to " + origin });
        init = false;
        context.statusCallback({ status: "ready" });
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
    context.targetsCallback(authRequest.targets?.slice()?.join(",\n") || "");
    const nonce = uint8ArrayToHex(authRequest.sessionPublicKey);
    context.statusCallback({ status: "ready", message: "" });

    // Get delegation from backend
    let msg;
    if (context.provider === "github" || context.provider === "x") {
      const pkceAuthData = await context.getPkceAuthData(
        authRequest.sessionPublicKey,
      );
      msg = await getDelegationPkce(
        context.provider,
        pkceAuthData.code,
        pkceAuthData.verifier,
        origin,
        authRequest.sessionPublicKey,
        authRequest.maxTimeToLive,
        authRequest.targets,
        context.statusCallback,
      );
    } else {
      const idToken = await context.getJwtToken(nonce);
      msg = await getDelegationJwt(
        context.provider,
        idToken,
        origin,
        authRequest.sessionPublicKey,
        authRequest.maxTimeToLive,
        authRequest.targets,
        context.statusCallback,
      );
    }

    // send response; window will be closed by opener
    responder(msg);
  } catch (err: any) {
    console.error("Error handling authorize-client request:", err);
    context.statusCallback({ status: "error", error: err.toString() });
    responder({ kind: "authorize-error", error: err.toString() });
  }
};
