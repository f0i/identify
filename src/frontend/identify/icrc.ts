import { AuthResponseUnwrapped } from "./utils";
import { JsonRpcRequest, JsonRpcResponse } from "./jsonrpc";
import * as icrc25 from "./icrc25_signer_integration";
import * as icrc29 from "./icrc29_status";
import * as icrc34 from "./icrc34_delegation";
import * as icrc27 from "./icrc27_accounts";
import * as icrc49 from "./icrc49_call_canister";
import * as jsonrpc from "./jsonrpc";

export type Context = {
  authResponse?: AuthResponseUnwrapped;
};

export const handleJSONRPC = async (
  data: JsonRpcRequest,
  responder: (res: JsonRpcResponse) => void,
  statusCallback: (msg: string) => void,
  targetsCallback: (msg: string) => void,
  getAuthToken: (nonce: string) => Promise<string>,
  context: Context,
  setContext: (context: Context) => void,
) => {
  switch (data.method) {
    case "icrc25_request_permissions": {
      responder(await icrc25.requestPermissions(data));
      break;
    }

    case "icrc25_permissions": {
      responder(await icrc25.permissions(data));
      break;
    }

    case "icrc25_supported_standards": {
      responder(await icrc25.supportedStandards(data));
      break;
    }

    case "icrc29_status": {
      responder(icrc29.ready(data));
      break;
    }

    case "icrc34_delegation": {
      responder(
        await icrc34.delegation(
          data,
          statusCallback,
          targetsCallback,
          getAuthToken,
          setContext,
        ),
      );
      break;
    }

    case "icrc27_accounts": {
      responder(await icrc27.accounts(data));
      break;
    }

    case "icrc49_call_canister": {
      responder(
        await icrc49.callCanister(
          data,
          statusCallback,
          targetsCallback,
          getAuthToken,
          setContext,
        ),
      );
      break;
    }

    default: {
      console.warn("unhandled JSONRPC call", data);
      responder(jsonrpc.methodNotFound(data));
    }
  }
};
