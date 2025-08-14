import { Principal } from "@dfinity/principal";
import { canisterId, createActor } from "../../declarations/backend";
import { AuthResponseUnwrapped, unwrapTargets, wrapOpt } from "./utils";
import { Provider } from "../../declarations/backend/backend.did";

export type DelegationParams = {
  publicKey: string;
  targets?: string[];
  maxTimeToLive?: string;
};

export type ProviderKey = Provider extends { [K in string]: null }
  ? keyof Provider
  : never;

export function getProviderName(provider: ProviderKey): string {
  const p = provider.toString();
  return p.charAt(0).toUpperCase() + p.slice(1);
}

/// Get delegation from backend using the auth token
/// @param idToken The ID token from Google sign-in
/// @param origin The origin of the request
/// @param sessionPublicKey The public key of the browser session
/// @param maxTimeToLive The maximum time the delegation is valid for
/// @param targets Optional list of target canisters which the delegation is valid for
export const getDelegationJwt = async (
  provider: ProviderKey,
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

  const name = getProviderName(provider);

  statusCallback(name + " sign in succeeded. Authorizing client...");

  let prepRes = await backend.prepareDelegation(
    { [provider]: null } as Provider,
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
  statusCallback(name + " sign in succeeded. Get client authorization...");

  let authRes = await backend.getDelegation(
    { [provider]: null } as Provider,
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
    const msg = unwrapTargets(authRes.ok.auth);
    console.log("getDelegation response unwrapped:", msg);
    return msg;
  } else {
    throw "Could not sign in: " + authRes.err;
  }
};

/// Get delegation from backend using the PKCE flow
export const getDelegationPkce = async (
  provider: ProviderKey,
  code: string,
  code_verifier: string,
  origin: string,
  sessionPublicKey: Uint8Array,
  maxTimeToLive: bigint,
  targets: undefined | Principal[],
  statusCallback: (msg: string) => void,
): Promise<AuthResponseUnwrapped> => {
  const isDev = process.env.DFX_NETWORK !== "ic";
  const host = isDev ? "http://localhost:4943" : "https://icp-api.io";

  const backend = createActor(canisterId, { agentOptions: { host } });

  const name = getProviderName(provider);

  statusCallback(name + " sign in succeeded. Authorizing client...");

  let prepRes = await backend.prepareDelegationPKCE(
    { [provider]: null } as Provider,
    code,
    code_verifier,
    origin,
    sessionPublicKey,
    maxTimeToLive,
    wrapOpt(targets),
  );
  if ("ok" in prepRes) {
    console.log("prepareDelegationPkce response:", prepRes.ok);
  } else {
    throw prepRes.err;
  }
  statusCallback(name + " sign in succeeded. Get client authorization...");

  let authRes = await backend.getDelegationPKCE(
    { [provider]: null } as Provider,
    code,
    code_verifier,
    origin,
    sessionPublicKey,
    prepRes.ok.expireAt,
    wrapOpt(targets),
  );

  console.log("getDelegationPkce response:", authRes);

  if ("ok" in authRes) {
    console.log("authRes", authRes.ok);
    statusCallback("Login completed");
    const msg = unwrapTargets(authRes.ok.auth);
    console.log("getDelegationPkce response unwrapped:", msg);
    return msg;
  } else {
    throw "Could not sign in: " + authRes.err;
  }
};
