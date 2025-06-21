import { AuthResponse } from "../../declarations/backend/backend.did";

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

export function wrapOpt(val?: any): [] | [any] {
  if (val === undefined) return [];
  return [val];
}

export function uint8ArrayToHex(array: Uint8Array): string {
  return Array.from(array)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function base64decode(base64: string): Uint8Array {
  const bin = atob(base64);
  const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
  return bytes;
}

export function base64encode(bytes: Uint8Array | number[]): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
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

export const jsonBigintReplacer = (key: string, value: any): any => {
  if (typeof value === "bigint") {
    return value.toString();
  }
  return value;
};
