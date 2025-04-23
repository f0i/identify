import Ed25519 "Ed25519";
import ULEB128 "ULEB128";
import Int "mo:base/Int";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Sha256 "mo:sha2/Sha256";
module {
  public type Delegation = {
    delegation : {
      pubkey : [Nat8];
      expiration : Int;
      targets : ?[Principal];
    };
    signature : [Nat8];
  };

  public type AuthResponse = {
    kind : Text;
    delegations : [Delegation];
    userPublicKey : [Nat8];
    authnMethod : Text;
  };

  let kind = "authorize-client-success";
  let authnMethod = "gsi"; // II uses "passkey"

  /// sessionKey: DER encoded session key as provided by the auth-client, including a domain separator
  public func getUnsignedBytes(sessionKey : [Nat8], expiration : Int, targetsOpt : ?[Principal]) : [Nat8] {

    // SHA256("expiration") = "2EEA88AC2BAA11E3A7468126879609105E6DB78F210978EE00BDDB13FCD8CC4C"
    let expHash : [Nat8] = [0x2E, 0xEA, 0x88, 0xAC, 0x2B, 0xAA, 0x11, 0xE3, 0xA7, 0x46, 0x81, 0x26, 0x87, 0x96, 0x09, 0x10, 0x5E, 0x6D, 0xB7, 0x8F, 0x21, 0x09, 0x78, 0xEE, 0x00, 0xBD, 0xDB, 0x13, 0xFC, 0xD8, 0xCC, 0x4C];
    let expirationBytes = ULEB128.encode(Int.abs(expiration));
    let expirationHash : [Nat8] = Blob.toArray(Sha256.fromArray(#sha256, expirationBytes));

    // SHA256("pubkey") = "B84B25628F800E36925811AA24AAF28C9F827333D2DF990762B5C3A86EFF7C9B"
    let pubHash : [Nat8] = [0xB8, 0x4B, 0x25, 0x62, 0x8F, 0x80, 0x0E, 0x36, 0x92, 0x58, 0x11, 0xAA, 0x24, 0xAA, 0xF2, 0x8C, 0x9F, 0x82, 0x73, 0x33, 0xD2, 0xDF, 0x99, 0x07, 0x62, 0xB5, 0xC3, 0xA8, 0x6E, 0xFF, 0x7C, 0x9B];
    let pubkeyHash : [Nat8] = Blob.toArray(Sha256.fromArray(#sha256, sessionKey));

    // concat and hash
    let concatenated : [Nat8] = switch (targetsOpt) {
      case (?targets) {
        // SHA256("targets") = 26CAFB94003A654827F52047A9368C0821F01F4512828A68F7BD4B44E6A0AFCF
        let targetsHash : [Nat8] = [0x26, 0xCA, 0xFB, 0x94, 0x00, 0x3A, 0x65, 0x48, 0x27, 0xF5, 0x20, 0x47, 0xA9, 0x36, 0x8C, 0x08, 0x21, 0xF0, 0x1F, 0x45, 0x12, 0x82, 0x8A, 0x68, 0xF7, 0xBD, 0x4B, 0x44, 0xE6, 0xA0, 0xAF, 0xCF];
        let targetsArrayHash = principalArrayHash(targets);

        //Debug.print("hashes: " # debug_show [targetsHash, targetsArrayHash, expHash, expirationHash, pubHash, pubkeyHash]);
        Array.flatten([targetsHash, targetsArrayHash, expHash, expirationHash, pubHash, pubkeyHash]);
      };

      case (null) {
        //Debug.print("hashes: " # debug_show [expHash, expirationHash, pubHash, pubkeyHash]);
        Array.flatten([expHash, expirationHash, pubHash, pubkeyHash]);
      };
    };
    let concatHash = Blob.toArray(Sha256.fromArray(#sha256, concatenated));
    //Debug.print("hashed: " # debug_show concatHash);

    // add domain seperator "\x1Aic-request-auth-delegation" (first byte is length)
    let domainSeparator : [Nat8] = [0x1A, 0x69, 0x63, 0x2d, 0x72, 0x65, 0x71, 0x75, 0x65, 0x73, 0x74, 0x2d, 0x61, 0x75, 0x74, 0x68, 0x2d, 0x64, 0x65, 0x6c, 0x65, 0x67, 0x61, 0x74, 0x69, 0x6f, 0x6e];

    return Array.flatten<Nat8>([domainSeparator, concatHash]);
  };

  private func principalArrayHash(targets : [Principal]) : [Nat8] {
    // https://github.com/dfinity/response-verification/blob/88f144ce1e32498adeb8a81872146c64ca587a7d/packages/ic-representation-independent-hash/src/representation_independent_hash.rs#L52
    let hashes = Array.tabulate(
      targets.size(),
      func(i : Nat) : [Nat8] {
        Blob.toArray(Sha256.fromBlob(#sha256, Principal.toBlob(targets[i])));
      },
    );
    // TODO: performance optimize Array.flatten becaus size is know. Also consider concating Blobs
    let arrayHash = Blob.toArray(Sha256.fromArray(#sha256, Array.flatten(hashes)));

    return arrayHash;
  };

  /// Get sha256 hash of representation independend map of public key and expiration, including the domain saparator
  public func getUnsignedHash(sessionKey : [Nat8], expiration : Int, targets : ?[Principal]) : [Nat8] {
    let unsigned = getUnsignedBytes(sessionKey, expiration, targets);
    let hash : [Nat8] = Blob.toArray(Sha256.fromArray(#sha256, unsigned));
    return hash;
  };

  /// Generate a delegation structure for given keys.
  /// sessionKey is alreadfy DER encoded and used as is.
  /// identityKeyPair is handing the delegation to the sessionKey
  /// the princial is determined by the identityKeyPair
  /// expirationh is the time in nanoseconds since 1970 when the delegation should expire
  public func getDelegation(sessionKey : [Nat8], identityKeyPair : Ed25519.KeyPair, expiration : Time.Time, targets : ?[Principal]) : AuthResponse {
    assert expiration > 0;

    // DER encode session key
    let pubkey = sessionKey;
    let unsigned = getUnsignedBytes(sessionKey, expiration, targets);

    //Debug.print("signing with: " # debug_show identityKeyPair);

    let signature = Ed25519.sign(unsigned, identityKeyPair.secretKey);

    let delegation = {
      delegation = {
        pubkey;
        expiration;
        targets;
      };
      signature;
    };
    return {
      kind;
      delegations = [delegation];
      userPublicKey = Ed25519.DERencodePubKey(identityKeyPair.publicKey);
      authnMethod;
    };
  };

  /// Generate a delegation structure for given keys.
  /// sessionKey is alreadfy DER encoded and used as is.
  /// usePublicKey is already DER encoded and used as is.
  /// signature is a cbor encoded signature.
  /// expirationh is the time in nanoseconds since 1970 when the delegation should expire
  public func getDelegationExternalSig(sessionKey : [Nat8], userPublicKey : [Nat8], signature : [Nat8], expiration : Time.Time, targets : ?[Principal]) : AuthResponse {
    let pubkey = sessionKey;

    let delegation = {
      delegation = {
        pubkey;
        expiration;
        targets;
      };
      signature;
    };
    return {
      kind;
      delegations = [delegation];
      userPublicKey;
      authnMethod;
    };
  };

};
