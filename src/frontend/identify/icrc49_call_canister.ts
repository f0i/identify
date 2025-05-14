import {
  JsonRpcRequest,
  JsonRpcResponse,
  setError,
  setResult,
} from "./jsonrpc";
import { Principal } from "@dfinity/principal";
import {
  base64decode,
  base64encode,
  delegationToJsonRPC,
  uint8ArrayToHex,
} from "./utils";
import { getDelegation } from "./delegation";
import { Context } from "./icrc";
import { HttpAgent } from "@dfinity/agent";

export const callCanister = async (
  req: JsonRpcRequest,
  statusCallback: (msg: string) => void,
  targetsCallback: (msg: string) => void,
  getAuthToken: (nonce: string) => Promise<string>,
  setContext: (context: Context) => void,
): Promise<JsonRpcResponse> => {
  if (!req.params) {
    console.error("missing params in icrc49_call_canister");
    return setError(req, -32602, "Invalid params for icrc49_call_canister");
  }

  let agent = new HttpAgent({});
  let params = req.params as any;
  let canisterId = params.canisterId;
  let sender = params.sender;
  let methodName = params.method;
  let arg = base64decode(params.arg);

  return setError(req, 2000, "WIP");
};
