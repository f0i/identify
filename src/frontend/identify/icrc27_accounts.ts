import { Scope } from "./icrc25_signer_integration";
import { JsonRpcRequest, setResult } from "./jsonrpc";

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

export const accounts = async (req: JsonRpcRequest) => {
  // TODO: get actuall accounts
  const dummyAccounts = [
    {
      owner: "qcsbg-57a6k-n3qcs-bqjw3-5tb5s-6sr4m-kfeio-mofuc-gni54-k2mar-gae",
    },
  ];

  return setResult(req, { accounts: dummyAccounts });
};
