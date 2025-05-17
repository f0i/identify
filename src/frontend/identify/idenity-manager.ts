/**
 * Identity Manager for handling WebCrypto session keys and Internet Identity delegations.
 *
 * - Generates and persists a session key pair using WebCrypto.
 * - Stores the public key in DER format.
 * - Stores and restores delegation chains.
 * - Provides a DelegationIdentity compatible with DFINITY agent APIs.
 */

import {
  Delegation,
  DelegationChain,
  DelegationIdentity,
  JsonnableDelegationChain,
  SignedDelegation,
} from "@dfinity/identity";
import {
  DerEncodedPublicKey,
  PublicKey,
  Signature,
  SignIdentity,
} from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import { AuthResponseUnwrapped, DelegationUnwrapped } from "./utils";
import { DelegationParams } from "./delegation";

// Utility functions for IndexedDB storage
const DB_NAME = "f0i-identify-db";
const STORE_NAME = "identity-store";

/**
 * Opens or initializes the IndexedDB database.
 * @returns A promise that resolves with the opened database.
 */
function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, 1);
    request.onupgradeneeded = () => {
      const db = request.result;
      db.createObjectStore(STORE_NAME);
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

/**
 * Saves a value into IndexedDB under the given key.
 * @param key Storage key.
 * @param value The value to store.
 */
async function saveToStore(key: string, value: any): Promise<void> {
  const db = await openDB();
  const tx = db.transaction(STORE_NAME, "readwrite");
  tx.objectStore(STORE_NAME).put(value, key);

  await new Promise<void>((resolve, reject) => {
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
    tx.onabort = () => reject(tx.error);
  });
}

/**
 * Retrieves a value from IndexedDB.
 * @param key Storage key.
 * @returns A promise resolving to the value or null.
 */
async function getFromStore<T = any>(key: string): Promise<T | null> {
  const db = await openDB();
  const tx = db.transaction(STORE_NAME, "readonly");
  return new Promise((resolve, reject) => {
    const request = tx.objectStore(STORE_NAME).get(key);
    request.onsuccess = () => resolve(request.result ?? null);
    request.onerror = () => reject(request.error);
  });
}

/**
 * WebCrypto-based SignIdentity implementation.
 */
class WebCryptoIdentity extends SignIdentity {
  constructor(
    private keyPair: CryptoKeyPair,
    private publicKeyDer: Uint8Array,
  ) {
    super();
    this._principal = Principal.selfAuthenticating(publicKeyDer);
  }

  async sign(blob: ArrayBuffer): Promise<Signature> {
    const signature: ArrayBuffer = await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      this.keyPair.privateKey,
      blob,
    );
    return signature as Signature;
  }

  getPublicKey(): PublicKey {
    return {
      toDer: () => this.publicKeyDer,
    };
  }

  // These are already implemented in SignIdentity:
  // - getPrincipal()
  // - transformRequest()
}

/**
 * Manages session key generation, delegation, and identity loading.
 */
export class IdentityManager {
  private keyPair: CryptoKeyPair | null = null;
  private publicKeyDer: Uint8Array | null = null;
  private identity: DelegationIdentity | null = null;

  /**
   * Generates a new session key pair and stores it.
   */
  async generateSessionKey(): Promise<void> {
    this.keyPair = await crypto.subtle.generateKey(
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["sign", "verify"],
    );

    const spki = await crypto.subtle.exportKey("spki", this.keyPair.publicKey);
    this.publicKeyDer = new Uint8Array(spki);

    await saveToStore("keyPair", this.keyPair);
    await saveToStore("publicKeyDer", this.publicKeyDer);
  }

  /**
   * Loads the session key pair from storage if available.
   * @returns Whether loading was successful.
   */
  async loadSessionKey(): Promise<boolean> {
    const keyPair = await getFromStore<CryptoKeyPair>("keyPair");
    const publicKeyDer = await getFromStore<Uint8Array>("publicKeyDer");

    if (!keyPair || !publicKeyDer) return false;

    this.keyPair = keyPair;
    this.publicKeyDer = publicKeyDer;
    return true;
  }

  /**
   * Gets the DER-encoded public key.
   * @returns DER-encoded public key as Uint8Array.
   */
  getPublicKeyDer(): Uint8Array {
    if (!this.publicKeyDer) throw new Error("Key not generated yet");
    return this.publicKeyDer;
  }

  /**
   * Sets the delegation chain and persists it.
   * @param delegation The delegation object from an auth provider.
   */
  async setDelegation(authRes: AuthResponseUnwrapped): Promise<void> {
    if (!this.keyPair || !this.publicKeyDer)
      throw new Error("Session key not initialized");

    const identity = new WebCryptoIdentity(this.keyPair, this.publicKeyDer);

    const signedDelegations: SignedDelegation[] = authRes.delegations.map(
      (d): SignedDelegation => ({
        delegation: new Delegation(
          new Uint8Array(d.delegation.pubkey).buffer,
          d.delegation.expiration,
          d.delegation.targets,
        ),
        signature: new Uint8Array(d.signature).buffer as Signature,
      }),
    );

    const chain = DelegationChain.fromDelegations(
      signedDelegations,
      new Uint8Array(authRes.userPublicKey).buffer as DerEncodedPublicKey,
    );
    this.identity = DelegationIdentity.fromDelegation(identity, chain);

    await saveToStore("delegation", chain);
  }

  /**
   * Checks if the stored delegation is valid for at least the given time.
   * @param minValiditySec Minimum validity in seconds (default: 60).
   * @returns True if the delegation is valid for at least the given time.
   */
  async isDelegationValid(minValiditySec = 60): Promise<boolean> {
    const delegation = await getFromStore<any>("delegation");
    if (!delegation) return false;

    const now = BigInt(Date.now()) * 1_000_000n;
    const minValidityNs = BigInt(minValiditySec) * 1_000_000_000n;
    return delegation.delegations.some(
      (d: any) => BigInt(d.delegation.expiration) > now + minValidityNs,
    );
  }

  /**
   * Loads the persisted delegation and builds the identity.
   * Will not load if the delegation is about to expire.
   * @returns Whether loading was successful.
   */
  async loadDelegation(): Promise<boolean> {
    const delegation = await getFromStore<any>("delegation");
    if (!delegation || !this.keyPair || !this.publicKeyDer) return false;

    const isValid = await this.isDelegationValid();
    if (!isValid) {
      await saveToStore("delegation", null);
      this.identity = null;
      return false;
    }

    const identity = new WebCryptoIdentity(this.keyPair, this.publicKeyDer);
    this.identity = DelegationIdentity.fromDelegation(identity, delegation);
    return true;
  }

  /**
   * Gets the current DelegationIdentity.
   * @returns The active DelegationIdentity.
   */
  getIdentity(): DelegationIdentity {
    if (!this.identity) throw new Error("Delegation identity not set");
    return this.identity;
  }
}
