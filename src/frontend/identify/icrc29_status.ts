import { Scope } from "./icrc25_signer_integration";
import { JsonRpcRequest, setResult } from "./jsonrpc";

export const STANDARD = {
  name: "ICRC-29",
  url: "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-29/ICRC-29.md",
};

export const SCOPES: Scope[] = [
  {
    method: "icrc29_ready",
    state: "granted",
  },
];

export const ready = (req: JsonRpcRequest) => {
  return setResult(req, "ready");
};
