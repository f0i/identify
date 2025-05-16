import { Principal } from "@dfinity/principal";
import { canisterId, createActor } from "../../declarations/backend";
import { AuthResponseUnwrapped, unwrapTargets, wrapOpt } from "./utils";

export type DelegationParams = {
  publicKey: string;
  targets?: string[];
  maxTimeToLive?: string;
};

async function handleCredentialResponse(
  response: { credential: string },
  sessionPublicKey: Uint8Array,
  maxTimeToLive: bigint,
  targets?: Principal[],
): Promise<AuthResponseUnwrapped> {
  return await getDelegation(
    response.credential,
    origin!,
    sessionPublicKey,
    maxTimeToLive,
    targets,
    statusCallback,
  );
}

export const getDelegation = async (
  idToken: string,
  origin: string,
  sessionPublicKey: Uint8Array,
  maxTimeToLive: bigint,
  targets: undefined | Principal[],
  statusCallback: (msg: string) => void,
): Promise<AuthResponseUnwrapped> => {
  // decode payload
  const payload = JSON.parse(atob(idToken.split(".")[1]));
  console.log("payload:", payload, payload.sub);

  const isDev = process.env.DFX_NETWORK !== "ic";
  const host = isDev ? "http://localhost:4943" : "https://icp-api.io";

  const backend = createActor(canisterId, { agentOptions: { host } });

  statusCallback("Google sign in succeeded. Authorizing client...");

  let prepRes = await backend.prepareDelegation(
    idToken,
    origin,
    sessionPublicKey,
    maxTimeToLive,
    wrapOpt(targets),
  );
  if ("ok" in prepRes) {
    console.log("prepareDelegation response:", prepRes.ok);
  } else {
    throw prepRes.err;
  }
  statusCallback("Google sign in succeeded. Get client authorization...");

  let authRes = await backend.getDelegation(
    idToken,
    origin,
    sessionPublicKey,
    prepRes.ok.expireAt,
    wrapOpt(targets),
  );

  console.log("getDelegation response:", authRes);

  if ("ok" in authRes) {
    console.log("authRes", authRes.ok);
    statusCallback("Login completed");
    debugger;
    // send response; window will be closed by opener
    const msg = unwrapTargets(authRes.ok.auth);
    console.log("getDelegation response unwrapped:", msg);
    return msg;
  } else {
    throw "Could not sign in: " + authRes.err;
  }
};
