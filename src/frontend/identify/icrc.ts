import { AuthResponseUnwrapped, uint8ArrayToHex } from "./utils";
import { JsonRpcRequest, JsonRpcResponse } from "./jsonrpc";
import * as icrc25 from "./icrc25_signer_integration";
import * as icrc29 from "./icrc29_status";
import * as icrc34 from "./icrc34_delegation";
import * as icrc27 from "./icrc27_accounts";
import * as icrc49 from "./icrc49_call_canister";
import * as jsonrpc from "./jsonrpc";
import { IdentityManager } from "./idenity-manager";
import { initGsi } from "./google";
import { getDelegation } from "./delegation";
import {
  AuthClient,
  InternetIdentityAuthResponseSuccess,
} from "../agent-js/packages/auth-client/src";

export type Context = {
  authResponse?: AuthResponseUnwrapped;
  gsiClientID?: string;
  origin?: string;
  statusCallback: (msg: string) => void;
  targetsCallback: (msg: string) => void;
  originCallback: (msg: string) => void;
  confirm: (msg: string) => Promise<boolean>;
  getAuthToken: (nonce: string) => Promise<string>;
};
export const DEFAULT_CONTEXT: Context = {
  // Callbacks can be sued to update the UI.
  statusCallback: (msg: string) => console.log("status", msg),
  targetsCallback: (msg: string) => console.log("targets", msg),
  originCallback: (msg: string) => console.log("origin", msg),
  // Default confirmation function allows all requests.
  // This is ok, because each origin gets its own identity.
  confirm: async (msg: string) => true,
  getAuthToken: async (nonce: string) => {
    console.error("getAuthToken not set in context (nonce:", nonce, ")");
    throw "Authentication mechanism not set";
  },
};

// Restore a delegation or fetch a new one if it does not exist.
export const loadOrFetchDelegation = async (
  context: Context,
): Promise<AuthClient> => {
  const origin = context.origin;
  if (!origin) throw "Internea error: app origin not set";
  let idManager = new IdentityManager();
  let authRes = await idManager.getDelegation(origin);
  if (!authRes) {
    if (!context.gsiClientID) throw "Internal error: gsiClientID not set";
    context.statusCallback("Starting a new session...");
    const sessionKey = await idManager.getPublicKeyDer();
    const maxTimeToLive = icrc34.DEFAULT_TTL;
    const targets = undefined;
    const nonce = uint8ArrayToHex(sessionKey);
    context.statusCallback("");
    const auth = await initGsi(context.gsiClientID, nonce);
    console.log("requesting delegation from backend");
    authRes = await getDelegation(
      auth.credential,
      origin,
      sessionKey,
      maxTimeToLive,
      targets,
      context.statusCallback,
    );
    await idManager.setDelegation(authRes, origin);
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
        context.statusCallback("Requesting permission...");
        responder(await icrc25.requestPermissions(data));
        break;
      }

      case "icrc25_permissions": {
        context.statusCallback("Loading permissions...");
        responder(await icrc25.permissions(data));
        break;
      }

      case "icrc25_supported_standards": {
        context.statusCallback("Loading supported standards...");
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
        context.statusCallback("Loading accounts...");
        responder(await icrc27.accounts(data, context));
        break;
      }

      case "icrc49_call_canister": {
        context.statusCallback("Calling canister...");
        responder(await icrc49.callCanister(data, context));
        break;
      }

      default: {
        console.warn("unhandled JSONRPC call", data);
        context.statusCallback("Unhandled request: " + data.method);
        await sleep(1000);
        responder(jsonrpc.methodNotFound(data));
      }
    }
  } catch (e: any) {
    console.error("Error handling JSONRPC request", data, e);
    context.statusCallback("Error: " + e);
    responder(jsonrpc.internalError(data, e.toString()));
  }
};
