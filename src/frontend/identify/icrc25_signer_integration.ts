import { AuthResponseUnwrapped } from "./utils";
import { JsonRpcRequest, JsonRpcResponse, setResult } from "./jsonrpc";

import * as icrc25 from "./icrc25_signer_integration";
import * as icrc27 from "./icrc27_accounts";
import * as icrc29 from "./icrc29_status";
import * as icrc34 from "./icrc34_delegation";
import * as icrc49 from "./icrc49_call_canister";
import * as jsonrpc from "./jsonrpc";

export type Scope = {
  method: string;
  state: "granted" | "denied" | "ask_on_use";
};
export type ScopeReq = {
  method: string;
};

export const STANDARD = {
  name: "ICRC-25",
  url: "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-25/ICRC-25.md",
};
export const SCOPES: Scope[] = [
  { method: "icrc25_request_permissions", state: "granted" },
  { method: "icrc25_permissions", state: "granted" },
  { method: "icrc25_supported_standards", state: "granted" },
];

//TODO?: move scopes and standards into context
const ALLSTANDARDS = [
  icrc25.STANDARD,
  icrc27.STANDARD,
  icrc29.STANDARD,
  icrc34.STANDARD,
  icrc49.STANDARD,
];
const ALLSCOPES = ([] as Scope[]).concat(
  icrc25.SCOPES,
  icrc27.SCOPES,
  icrc29.SCOPES,
  icrc34.SCOPES,
  icrc49.SCOPES,
);

export const requestPermissions = async (req: JsonRpcRequest) => {
  let requested = req.params?.scopes || [];

  let scopes = requested.map((scope: ScopeReq) => {
    let found = ALLSCOPES.find((s) => s.method === scope.method);
    if (found) return found;
    return { ...scope, state: "denied" };
  });

  return setResult(req, { scopes });
};

export const permissions = async (req: JsonRpcRequest) => {
  return setResult(req, { scopes: ALLSCOPES });
};

export const supportedStandards = async (req: JsonRpcRequest) => {
  return setResult(req, { supportedStandards: ALLSTANDARDS });
};
