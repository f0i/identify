import {
  JsonRpcRequest,
  JsonRpcResponse,
  setError,
  setResult,
} from "./jsonrpc";
import { base64decode } from "./utils";
import { Context, loadDelegation } from "./icrc";
import { HttpAgent, polling } from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import { Scope } from "./icrc25_signer_integration";
import { IdentityManager } from "./idenity-manager";
import { canister_call } from "./canister_caller";

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

  const idManager = new IdentityManager();
  loadDelegation(idManager, context);

  let agent = await HttpAgent.create({
    identity: idManager.getIdentity(origin),
  });

  const callResponse = await canister_call({
    canisterId: req.params.canisterId,
    calledMethodName: req.params.method,
    parameters: req.params.arg,
    agent,
  });

  console.log("icrc49_call_canister WIP: calling canister", callResponse);
  throw "WIP: success";

  let params = req.params as any;
  let canisterId = Principal.fromText(params.canisterId);
  let sender = params.sender;
  if (sender !== (await idManager.getPrincipal(origin)).toString()) {
    return setError(
      req,
      -32602,
      "Invalid sender for icrc49_call_canister " +
        sender +
        " != " +
        (await idManager.getPrincipal(origin)).toString(),
    );
  }
  let methodName = params.method;
  let arg = base64decode(params.arg);

  console.log(
    "icrc49_call_canister calling canister",
    canisterId,
    methodName,
    arg,
    req.params,
  );
  // For an update call:
  const { requestId } = await agent.call(canisterId, {
    methodName,
    arg,
    effectiveCanisterId: canisterId,
  });

  // All callse are update calls:
  // const queryResult = await agent.query(canisterId, {
  //  methodName,
  //  arg,
  //  // effectiveCanisterId (optional)
  //});
  console.log(
    "icrc49_call_canister polling for reponse",
    canisterId,
    requestId,
  );

  // Wait for the reply
  const response = await polling.pollForResponse(
    agent,
    canisterId,
    requestId,
    polling.defaultStrategy(),
  );

  return setResult(req, {
    contentMap: response.reply,
    certificate: response.certificate,
  });
};
