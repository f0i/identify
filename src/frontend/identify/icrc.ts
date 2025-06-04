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
import { Principal } from "../agent-js/packages/principal/src";

export type Context = {
  authResponse?: AuthResponseUnwrapped;
  gsiClientID?: string;
  origin?: string;
  statusCallback: (msg: string) => void;
  targetsCallback: (msg: string) => void;
  getAuthToken: (nonce: string) => Promise<string>;
};
export const DEFAULT_CONTEXT: Context = {
  statusCallback: (msg: string) => console.log(msg),
  targetsCallback: (msg: string) => console.log(msg),
  getAuthToken: async (nonce: string) => {
    console.error("getAuthToken not set in context (nonce:", nonce, ")");
    throw "Authentication mechanism not set";
  },
};

export const loadOrFetchDelegation = async (context: Context) => {
  const origin = context.origin;
  if (!origin) throw "App origin not set";
  let idManager = new IdentityManager();
  let authRes = await idManager.getDelegation(origin);
  if (!authRes) {
    if (!context.gsiClientID) throw "Internal error: gsiClientID not set";
    const sessionKey = await idManager.getPublicKeyDer();
    const maxTimeToLive = icrc34.DEFAULT_TTL;
    const targets = undefined;
    const nonce = uint8ArrayToHex(sessionKey);
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
  console.log(signIdentity.getPrincipal().toString());
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

export const handleJSONRPC = async (
  data: JsonRpcRequest,
  responder: (res: JsonRpcResponse) => void,
  context: Context,
) => {
  switch (data.method) {
    case "icrc25_request_permissions": {
      alert("ICRC " + data.method);
      responder(await icrc25.requestPermissions(data));
      break;
    }

    case "icrc25_permissions": {
      alert("ICRC " + data.method);
      responder(await icrc25.permissions(data));
      break;
    }

    case "icrc25_supported_standards": {
      alert("ICRC " + data.method);
      responder(await icrc25.supportedStandards(data));
      break;
    }

    case "icrc29_status": {
      responder(icrc29.ready(data));
      break;
    }

    case "icrc34_delegation": {
      alert("ICRC " + data.method);
      responder(await icrc34.delegation(data, context));
      break;
    }

    case "icrc27_accounts": {
      alert("ICRC " + data.method);
      responder(await icrc27.accounts(data, context));
      break;
    }

    case "icrc49_call_canister": {
      responder(await icrc49.callCanister(data, context));
      break;
    }

    default: {
      alert("ICRC " + data.method);
      console.warn("unhandled JSONRPC call", data);
      responder(jsonrpc.methodNotFound(data));
    }
  }
};
