export type JsonRpcRequest = {
  jsonrpc: "2.0";
  id: string;
  method: string;
  params?: any;
};

export type JsonRpcResult = {
  jsonrpc: "2.0";
  id: string;
  result: any;
};
export type JsonRpcError = {
  jsonrpc: "2.0";
  id: string;
  error: { code: number; message: string };
};
export type JsonRpcResponse = JsonRpcResult | JsonRpcError;

/// Create a data structure for the JSON-RPC response
export const setResult = (
  req: JsonRpcRequest,
  result: any,
): JsonRpcResponse => {
  return { jsonrpc: "2.0", id: req.id, result };
};

/// Create a data structure for the JSON-RPC error response
export const setError = (
  req: JsonRpcRequest,
  code: number,
  message: string,
): JsonRpcResponse => {
  return { jsonrpc: "2.0", id: req.id, error: { code, message } };
};

/// Error responses according to the JSON-RPC 2.0 specification
export const parseError = (req: JsonRpcRequest): JsonRpcResponse => {
  return setError(req, -32700, "Parse error");
};
export const invalidRequest = (req: JsonRpcRequest): JsonRpcResponse => {
  return setError(req, -32600, "Invalid request");
};
export const methodNotFound = (req: JsonRpcRequest): JsonRpcResponse => {
  return setError(req, -32601, "Method not found");
};
export const invalidParams = (req: JsonRpcRequest): JsonRpcResponse => {
  return setError(req, -32602, "Invalid params");
};
export const internalError = (
  req: JsonRpcRequest,
  msg?: string,
): JsonRpcResponse => {
  return setError(req, -32603, "Internal error" + (msg ? ": " + msg : ""));
};
export const serverError = (req: JsonRpcRequest): JsonRpcResponse => {
  return setError(req, -32000, "Server error");
};

/// Send a JSON-RPC response
export const respond = (
  req: JsonRpcRequest,
  action: (req: JsonRpcRequest) => JsonRpcResponse,
  sender: (res: JsonRpcResponse) => void,
) => {
  sender(action(req));
};
