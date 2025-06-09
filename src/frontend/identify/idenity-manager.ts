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
  SignedDelegation,
} from "@dfinity/identity";
import {
  DerEncodedPublicKey,
  PublicKey,
  Signature,
  SignIdentity,
} from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import { AuthResponseUnwrapped } from "./utils";

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
  private authRes: AuthResponseUnwrapped | null = null;

  /**
   * Restores a new session key pair or generates and stores it.
   */
  async loadSessionKey(recreate: boolean): Promise<void> {
    console.log("Loading session key...");
    const keyPair = await getFromStore<CryptoKeyPair>("keyPair");
    const publicKeyDer = await getFromStore<Uint8Array>("publicKeyDer");

    if (!recreate && keyPair && publicKeyDer) {
      this.keyPair = keyPair;
      this.publicKeyDer = publicKeyDer;
      console.log(
        "Loaded existing session key pair from store:",
        keyPair.publicKey,
      );
      return;
    }

    this.keyPair = await crypto.subtle.generateKey(
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["sign", "verify"],
    );

    const spki = await crypto.subtle.exportKey("spki", this.keyPair.publicKey);
    this.publicKeyDer = new Uint8Array(spki);

    await saveToStore("keyPair", this.keyPair);
    await saveToStore("publicKeyDer", this.publicKeyDer);
    console.log(
      "Created new session key pair and stored it:",
      this.keyPair.publicKey,
    );
  }

  async getSignIdentity(): Promise<SignIdentity> {
    await this.loadSessionKey(false);
    return new WebCryptoIdentity(this.keyPair!, this.publicKeyDer!);
  }

  /**
   * Gets the DER-encoded public key.
   * @returns DER-encoded public key as Uint8Array.
   */
  async getPublicKeyDer(): Promise<Uint8Array> {
    await this.loadSessionKey(false);
    return this.publicKeyDer!;
  }

  /**
   * Sets the delegation chain and persists it.
   * @param delegation The delegation object from an auth provider.
   */
  async setDelegation(
    authRes: AuthResponseUnwrapped,
    origin: string,
  ): Promise<void> {
    console.log("Setting delegation for", origin, "to", authRes);
    await saveToStore("delegation-" + origin, authRes);
  }

  /**
   * Return a valid delegation if it exists
   */
  async getDelegation(
    origin: string,
    minValiditySec = 60,
  ): Promise<AuthResponseUnwrapped | null> {
    const now = BigInt(Date.now()) * 1_000_000n;
    const minValidityNs = BigInt(minValiditySec) * 1_000_000_000n;

    const authRes = await getFromStore<AuthResponseUnwrapped>(
      "delegation-" + origin,
    );

    if (!authRes || !authRes.delegations || authRes.delegations.length === 0) {
      console.warn("No delegation found for", origin, authRes);
      console.trace();
      return null;
    }

    const expiration = authRes.delegations[0].delegation.expiration;
    const isValid: boolean = expiration > now + minValidityNs;
    console.log(
      "delegation expiration:",
      expiration,
      "now:",
      now,
      "minValidityNs:",
      minValidityNs,
      "validity:",
      isValid,
    );
    if (!isValid) return null;

    // TODO: check if the public key matches the stored delegation
    return authRes;
  }

  /**
   * Resets the delegation and identity, clearing stored values.
   */
  async resetDelegation(origin: string): Promise<void> {
    console.log("Resetting delegation and identity");
    await saveToStore("delegation-" + origin, null);
  }
}
