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
import { Scope } from "./icrc25_signer_integration";

export const DEFAULT_TTL = 30n * 60n * 1_000_000_000n;

export const STANDARD = {
  name: "ICRC-34",
  url: "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-34/ICRC-34.md",
};
export const SCOPES: Scope[] = [
  {
    method: "icrc34_delegation",
    state: "granted",
  },
];

export const delegation = async (
  req: JsonRpcRequest,
  statusCallback: (msg: string) => void,
  targetsCallback: (msg: string) => void,
  getAuthToken: (nonce: string) => Promise<string>,
  setContext: (context: Context) => void,
): Promise<JsonRpcResponse> => {
  if (!req.params) {
    console.error("missing params in icrc34_delegation");
    return setError(req, -32602, "Invalid params for icrc34_delegation");
  }
  const publicKey = base64decode(req.params?.publicKey);
  const maxTimeToLive = BigInt(req.params.maxTimeToLive || DEFAULT_TTL);
  const targets = req.params.targets?.map(
    (p: string): Principal => Principal.fromText(p),
  );
  statusCallback("");
  targetsCallback(req.params.targets?.slice()?.join(",\n") || "Unrestricted");
  const nonce = uint8ArrayToHex(publicKey);
  const token = await getAuthToken(nonce);
  const msg = await getDelegation(
    token,
    origin,
    publicKey,
    maxTimeToLive,
    targets,
    statusCallback,
  );

  setContext({ authResponse: msg });

  return setResult(req, {
    publicKey: base64encode(msg.userPublicKey),
    signerDelegation: msg.delegations.map(delegationToJsonRPC),
  });
};
