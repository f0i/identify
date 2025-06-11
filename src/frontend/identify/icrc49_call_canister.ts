import {
  JsonRpcRequest,
  JsonRpcResponse,
  setError,
  setResult,
} from "./jsonrpc";
import { Context, loadOrFetchDelegation } from "./icrc";
import { HttpAgent } from "@dfinity/agent";
import { Scope } from "./icrc25_signer_integration";
import { canister_call } from "./canister_caller";
import { base64decode } from "./utils";
import { decode } from "@dfinity/candid/lib/cjs/idl";

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
  context: Context,
): Promise<JsonRpcResponse> => {
  if (!req.params) {
    console.error("missing params in icrc49_call_canister");
    return setError(req, -32602, "Invalid params for icrc49_call_canister");
  }

  const origin = context.origin;
  if (!origin) throw "App origin is not set";

  const authClient = await loadOrFetchDelegation(context);

  let agent = await HttpAgent.create({
    identity: authClient.getIdentity(),
  });

  console.log(
    "calling canister with agent id",
    authClient.getIdentity().getPrincipal().toString(),
    (await agent.getPrincipal()).toString(),
  );

  await new Promise<void>((resolve, reject) => setTimeout(resolve, 5000)); // wait for the agent to be ready
  debugger;
  context.statusCallback(
    "Calling canister " +
      req.params.canisterId.toString() +
      "\nmethod: " +
      req.params.method +
      "\narg: " +
      JSON.stringify(decode([], base64decode(req.params.arg))),
  );

  const callResponse = await canister_call({
    canisterId: req.params.canisterId,
    calledMethodName: req.params.method,
    parameters: req.params.arg,
    agent,
  });

  console.log("icrc49_call_canister WIP: calling canister", callResponse);
  return setResult(req, {
    contentMap: callResponse.contentMap,
    certificate: callResponse.certificate,
  });
};
