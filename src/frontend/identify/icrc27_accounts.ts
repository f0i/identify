import { Scope } from "./icrc25_signer_integration";
import { JsonRpcRequest, setResult } from "./jsonrpc";
import { Context, loadDelegation } from "./icrc";
import { IdentityManager } from "./idenity-manager";
import { getDelegation } from "./delegation";

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
  await loadDelegation(idManager, context);
  const origin = context.origin;
  if (!origin) throw "App origin is not set";
  const id = await idManager.getIdentity(origin);
  const principal = id.getPrincipal();

  const accounts = [
    {
      owner: principal.toString(),
    },
  ];

  return setResult(req, { accounts: accounts });
};
