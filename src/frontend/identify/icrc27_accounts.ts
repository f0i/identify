import { setDefaultAutoSelectFamily } from "net";
import { JsonRpcRequest, setResult } from "./jsonrpc";

export const accounts = async (req: JsonRpcRequest) => {
  // TODO: get actuall accounts
  const dummyAccounts = [
    {
      owner: "qcsbg-57a6k-n3qcs-bqjw3-5tb5s-6sr4m-kfeio-mofuc-gni54-k2mar-gae",
    },
  ];

  return setResult(req, { accounts: dummyAccounts });
};
