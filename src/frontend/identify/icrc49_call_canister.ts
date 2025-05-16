import { JsonRpcRequest, JsonRpcResponse, setError } from "./jsonrpc";
import { base64decode } from "./utils";
import { Context } from "./icrc";
import { HttpAgent } from "@dfinity/agent";
import { Scope } from "./icrc25_signer_integration";

export const STANDARD = {
  name: "ICRC-49",
  url: "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-49/ICRC-49.md",
};
export const SCOPES: Scope[] = [
  {
    method: "icrc49_call_canister",
    state: "ask_on_use",
  },
];

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

  // TODO: use identity from context
  // TODO: if identity is not avaliable: request sign in?

  let agent = new HttpAgent({});
  let params = req.params as any;
  let canisterId = params.canisterId;
  let sender = params.sender;
  let methodName = params.method;
  let arg = base64decode(params.arg);

  return setError(req, 2000, "WIP");
};
