import { getDelegation } from "./delegation";
import { Scope } from "./icrc25_signer_integration";
import { JsonRpcRequest, setResult } from "./jsonrpc";
import { Ed25519KeyIdentity } from "@dfinity/identity";
import { Principal } from "@dfinity/principal";
import { uint8ArrayToHex } from "./utils";
import { initGsi } from "./google";
import { Context } from "./icrc";
import { DEFAULT_TTL } from "./icrc34_delegation";
import { IdentityManager } from "./idenity-manager";

export const STANDARD = {
  name: "ICRC-27",
  url: "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-27/ICRC-27.md",
};

export const SCOPES: Scope[] = [
  {
    method: "icrc27_accounts",
    state: "granted",
  },
];

export const accounts = async (req: JsonRpcRequest, context: Context) => {
  let idManager = new IdentityManager();
  if (!(await idManager.isDelegationValid())) {
    if (!context.gsiClientID) throw "Internal error: gsiClientID not set";
    await idManager.generateSessionKey();
    const sessionKey = idManager.getPublicKeyDer();
    const origin = context.origin;
    const maxTimeToLive = DEFAULT_TTL;
    const targets = undefined;
    const nonce = uint8ArrayToHex(sessionKey);
    const auth = await initGsi(context.gsiClientID, nonce);
    let authRes = await getDelegation(
      auth.credential,
      origin || document.location.origin,
      sessionKey,
      maxTimeToLive,
      targets,
      context.statusCallback ?? console.log,
    );
    idManager.setDelegation(authRes);
    // get principal from delegation
  }
  const id = idManager.getIdentity();
  const principal = id.getPrincipal();

  const dummyAccounts = [
    {
      owner: principal.toString(),
    },
  ];

  return setResult(req, { accounts: dummyAccounts });
};
