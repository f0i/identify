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
import { base64decode, jsonBigintReplacer, JSONstringify } from "./utils";
import { decodeCandid } from "./candidDecoder";
import { fieldNames } from "./candidFieldNames";

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
  const argData = decodeCandid(base64decode(req.params.arg), fieldNames);
  let argText = req.params.arg;
  if ("ok" in argData) {
    argText = JSONstringify(argData.ok);
  } else if ("error" in argData) {
    argText +=
      "\n(decoding error: " +
      argData.error.msg +
      " at byte " +
      argData.error.index +
      ")";
  } else if ("warning" in argData) {
    argText =
      JSONstringify(argData.warning.data) +
      "\n(warning: " +
      argData.warning.msg +
      ")";
  }

  context.statusCallback(
    "Calling canister " +
      req.params.canisterId.toString() +
      "\nmethod: " +
      req.params.method +
      "\narg: " +
      argText,
  );

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

  context.statusCallback(
    "Calling canister " +
      req.params.canisterId.toString() +
      "\nmethod: " +
      req.params.method +
      "\narg: " +
      argText,
  );

  // TODO?: ask for confimation before calling the canister
  await new Promise<void>((resolve) => setTimeout(resolve, 15000)); // wait some seconds for debugging

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
