import { AuthResponseUnwrapped, uint8ArrayToHex } from "./utils";
import { JsonRpcRequest, JsonRpcResponse } from "./jsonrpc";
import * as icrc25 from "./icrc25_signer_integration";
import * as icrc29 from "./icrc29_status";
import * as icrc34 from "./icrc34_delegation";
import * as icrc27 from "./icrc27_accounts";
import * as icrc49 from "./icrc49_call_canister";
import * as jsonrpc from "./jsonrpc";
import { IdentityManager } from "./idenity-manager";
import { getDelegationJwt, getDelegationPkce } from "./delegation";
import {
  AuthClient,
  InternetIdentityAuthResponseSuccess,
} from "../agent-js/packages/auth-client/src";
import { AuthConfig, getProvider } from "../auth-config";
import { DOM_IDS } from "../dom-config";
import { PkceAuthData } from "../pkce";
import { initOIDC, OidcAuthData } from "../oidc-implicit";
import { ProviderKey } from "../../declarations/backend/backend.did";

export type Status = "loading" | "ready" | "error" | "signing-in";
export type StatusUpdate = {
  status: Status;
  message?: string;
  error?: string;
};

export type Context = {
  authResponse?: AuthResponseUnwrapped;
  providerKey: ProviderKey;
  origin?: string;
  statusCallback: (update: StatusUpdate) => void;
  targetsCallback: (msg: string) => void;
  originCallback: (msg: string) => void;
  confirm: (msg: string) => Promise<boolean>;
  getJwtToken: (nonce: string) => Promise<OidcAuthData>;
  getPkceAuthData: (sessionKey: Uint8Array) => Promise<PkceAuthData>;
  cancel: () => void;
};
export const DEFAULT_CONTEXT: Context = {
  providerKey: "google",
  // Callbacks can be sued to update the UI.
  statusCallback: (update: StatusUpdate) => console.log("status", update),
  targetsCallback: (msg: string) => console.log("targets", msg),
  originCallback: (msg: string) => console.log("origin", msg),
  // Default confirmation function allows all requests.
  // This is ok, because each origin gets its own identity.
  confirm: async (msg: string) => {
    console.warn("Agree to transaction without user interaction:", msg);
    return true;
  },
  getJwtToken: async (nonce: string) => {
    console.error("getJwtToken not set in context (nonce:", nonce, ")");
    throw "Authentication mechanism not set";
  },
  getPkceAuthData: async (sessionKey: Uint8Array) => {
    console.error(
      "getPkceAuthData not set in context (nonce:",
      sessionKey,
      ")",
    );
    throw "Authentication mechanism not set";
  },
  cancel: () => {
    console.log("cancel not set in context");
  },
};

// Restore a delegation or fetch a new one if it does not exist.
export const loadOrFetchDelegation = async (
  context: Context,
): Promise<AuthClient> => {
  const origin = context.origin;
  if (!origin) throw "Internea error: app origin not set";
  let idManager = new IdentityManager();
  let idAuthRes = await idManager.getDelegation(origin);
  let authRes: AuthResponseUnwrapped = idAuthRes!;
  if (!idAuthRes) {
    context.statusCallback({
      status: "loading",
      message: "Starting a new session...",
    });
    const sessionKey = await idManager.getPublicKeyDer();
    const maxTimeToLive = icrc34.DEFAULT_TTL;
    const targets = undefined;
    const nonce = uint8ArrayToHex(new Uint8Array(sessionKey));
    context.statusCallback({
      status: "loading",
      message: "Loading configuration",
    });
    let config = await getProvider(context.providerKey);
    context.statusCallback({ status: "ready" });
    if (config.auth_type === "OIDC") {
      const idToken = await initOIDC(
        config,
        nonce,
        DOM_IDS.singinBtn,
        true,
        context.statusCallback,
      );
      console.log("requesting delegation from backend");
      authRes = await getDelegationJwt(
        context.providerKey,
        idToken,
        origin,
        new Uint8Array(sessionKey),
        maxTimeToLive,
        targets,
        context.statusCallback,
      );

      await idManager.setDelegation(authRes, origin);
    } else if (config.auth_type === "PKCE") {
      const pkceAuthData = await context.getPkceAuthData(
        new Uint8Array(sessionKey),
      );
      authRes = await getDelegationPkce(
        context.providerKey,
        pkceAuthData.code,
        pkceAuthData.verifier,
        origin,
        new Uint8Array(sessionKey),
        maxTimeToLive,
        targets,
        context.statusCallback,
      );

      await idManager.setDelegation(authRes, origin);
    } else {
      // type check that all variants have been consumed in other brances already
      config satisfies never;
      throw (
        "Unsupported authentication type: " + (config as AuthConfig).auth_type
      );
    }
  }

  const signIdentity = await idManager.getSignIdentity();
  const authClient = await AuthClient.create({
    identity: signIdentity,
  });

  const iiauthRes: InternetIdentityAuthResponseSuccess = {
    kind: "authorize-client-success",
    delegations: authRes.delegations,
    userPublicKey: authRes.userPublicKey,
    authnMethod: authRes.authnMethod as "pin",
  };

  authClient.handleSuccess(iiauthRes);
  console.log("setting delegation:", authRes);
  return authClient;
};

const sleep = async (ms: number) =>
  new Promise((resolve) => setTimeout(resolve, ms));

export const handleJSONRPC = async (
  data: JsonRpcRequest,
  responder: (res: JsonRpcResponse) => void,
  context: Context,
) => {
  try {
    switch (data.method) {
      case "icrc25_request_permissions": {
        context.statusCallback({
          status: "loading",
          message: "Requesting permission...",
        });
        responder(await icrc25.requestPermissions(data));
        break;
      }

      case "icrc25_permissions": {
        context.statusCallback({
          status: "loading",
          message: "Loading permissions...",
        });
        responder(await icrc25.permissions(data));
        break;
      }

      case "icrc25_supported_standards": {
        context.statusCallback({
          status: "loading",
          message: "Loading supported standards...",
        });
        responder(await icrc25.supportedStandards(data));
        break;
      }

      case "icrc29_status": {
        // This is happening in the background, so no status callback needed.
        responder(icrc29.ready(data));
        break;
      }

      case "icrc34_delegation": {
        responder(await icrc34.delegation(data, context));
        break;
      }

      case "icrc27_accounts": {
        context.statusCallback({
          status: "loading",
          message: "Loading accounts...",
        });
        responder(await icrc27.accounts(data, context));
        break;
      }

      case "icrc49_call_canister": {
        context.statusCallback({
          status: "loading",
          message: "Calling canister...",
        });
        responder(await icrc49.callCanister(data, context));
        break;
      }

      default: {
        console.warn("unhandled JSONRPC call", data);
        context.statusCallback({
          status: "error",
          error: "Unhandled request: " + data.method,
        });
        await sleep(1000);
        responder(jsonrpc.methodNotFound(data));
      }
    }
  } catch (e: any) {
    console.error("Error handling JSONRPC request", data, e);
    context.statusCallback({ status: "error", error: e.toString() });
    responder(jsonrpc.internalError(data, e.toString()));
  }
};
