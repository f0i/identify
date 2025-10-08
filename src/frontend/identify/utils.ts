import {
  AuthResponse,
  FrontendOAuth2Config,
} from "../../declarations/backend/backend.did";
import { AuthConfig } from "../auth-config";

export interface AuthResponseUnwrapped {
  kind: string;
  delegations: Array<DelegationUnwrapped>;
  authnMethod: string;
  userPublicKey: Uint8Array;
}
export interface DelegationUnwrapped {
  signature: Uint8Array;
  delegation: {
    pubkey: Uint8Array;
    targets?: Array<any>;
    expiration: bigint;
  };
}

export function unwrapTargets(authRes: AuthResponse): AuthResponseUnwrapped {
  return {
    ...authRes,
    delegations: authRes.delegations.map((d): DelegationUnwrapped => {
      const { targets, ...delegation } = d.delegation;

      if (targets.length > 0)
        return {
          ...d,
          delegation: { ...delegation, targets: targets[0] },
        } as DelegationUnwrapped;
      else return { ...d, delegation } as DelegationUnwrapped;
    }),
  } as AuthResponseUnwrapped;
}

export function wrapOpt<T>(val?: T): [] | [T] {
  if (val === undefined) return [];
  return [val];
}

export function unwrapOpt<T>(val: [] | [T]): T | undefined {
  if (val.length === 0) return undefined;
  return val[0];
}

export function unwrapEnum<T>(
  val: Record<string, T>,
): string | Record<string, T> {
  const keys = Object.keys(val);
  if (keys.length !== 1) {
    console.warn(
      "Expected exactly one key in enum value, but got ",
      keys,
      "in",
      val,
    );
    return val;
  }
  if (val[keys[0]] !== null) return val;
  return keys[0];
}

export const unwrapProvider = (config: FrontendOAuth2Config): AuthConfig => {
  if ("jwt" in config.auth) {
    const jwt = config.auth.jwt;
    return {
      auth_type: "OIDC",
      client_id: jwt.clientId,
      name: config.name,
      scope: jwt.scope,
      authority: jwt.authority,
      authorization_url: jwt.authorizationUrl,
      response_type: jwt.responseType as "id_token",
      fedCM_config_url: unwrapOpt(jwt.fedCMConfigUrl),
    };
  }
  if ("pkce" in config.auth) {
    const pkce = config.auth.pkce;
    return {
      auth_type: "PKCE",
      client_id: pkce.clientId,
      name: config.name,
      authorization_url: pkce.authorizationUrl,
      token_url: pkce.tokenUrl,
      scope: pkce.scope,
      user_info_endpoint: pkce.userInfoEndpoint,
    };
  }
  throw "Unsupported provider configuration: " + JSONstringify(config);
};

export function uint8ArrayToHex(array: Uint8Array): string {
  return Array.from(array)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function base64decode(base64: string): Uint8Array {
  const bin = base64decodeText(base64);
  const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
  return bytes;
}

export function base64decodeText(base64: string): string {
  let str = base64.replace(/-/g, "+").replace(/_/g, "/");
  while (str.length % 4) {
    str += "=";
  }
  return atob(str);
}

export function base64encode(
  bytes: Uint8Array | number[],
  urlEncode: boolean = false,
): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  if (urlEncode) {
    return btoa(binary)
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=/g, "");
  }
  return btoa(binary);
}

export function delegationToJsonRPC(delegation: DelegationUnwrapped): {
  delegation: {
    pubkey: string;
    expiration: string;
    targets?: string[];
  };
  signature: string;
} {
  return {
    delegation: {
      pubkey: base64encode(delegation.delegation.pubkey),
      targets: delegation.delegation.targets?.map((p) => p.toString()),
      expiration: delegation.delegation.expiration.toString(),
    },
    signature: base64encode(delegation.signature),
  };
}

export const JSONstringify = (obj: any, indent?: number): string => {
  return JSON.stringify(obj, jsonBigintReplacer, indent);
};

export const jsonBigintReplacer = (_key: string, value: any): any => {
  if (typeof value === "bigint") {
    return value.toString();
  }
  return value;
};

export function generateRandomString(length: number) {
  const array = new Uint32Array(length / 2);
  window.crypto.getRandomValues(array);
  return Array.from(array, dec2hex).join("");
}

function dec2hex(dec: number) {
  const out = dec.toString(16);
  return out.length == 1 ? "0" + out : out;
}

export async function sha256(input: string): Promise<Uint8Array> {
  const encoder = new TextEncoder();
  const data = encoder.encode(input);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  return new Uint8Array(hashBuffer);
}
