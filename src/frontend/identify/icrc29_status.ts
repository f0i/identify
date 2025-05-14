import { setDefaultAutoSelectFamily } from "net";
import { JsonRpcRequest } from "./jsonrpc";

export const ready = (req: JsonRpcRequest) => {
  return setResult(req, "ready");
};
