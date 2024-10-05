import Ed25519 "Ed25519";
import ULEB128 "ULEB128";
import Int "mo:base/Int";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Sha256 "mo:sha2/Sha256";
module {
  public type AuthResponse = {
    kind : Text;
    delegations : [{
      delegation : {
        pubkey : [Nat8];
        expiration : Int;
        targets : ?[Principal];
      };
      signature : [Nat8];
    }];
    userPublicKey : [Nat8];
    authnMethod : Text;
  };

  let kind = "authorize-client-success";
  let authnMethod = "gsi"; // II uses "passkey";

  public func getDelegation(sessionKey : [Nat8], identityKeyPair : Ed25519.KeyPair, expiration : Int) : AuthResponse {
    assert expiration > 0;
    let expirationBytes = ULEB128.encode(Int.abs(expiration));

    // SHA256("expiration") = "2EEA88AC2BAA11E3A7468126879609105E6DB78F210978EE00BDDB13FCD8CC4C"
    let expHash : [Nat8] = [0x2E, 0xEA, 0x88, 0xAC, 0x2B, 0xAA, 0x11, 0xE3, 0xA7, 0x46, 0x81, 0x26, 0x87, 0x96, 0x09, 0x10, 0x5E, 0x6D, 0xB7, 0x8F, 0x21, 0x09, 0x78, 0xEE, 0x00, 0xBD, 0xDB, 0x13, 0xFC, 0xD8, 0xCC, 0x4C];
    let expirationHash : [Nat8] = Blob.toArray(Sha256.fromArray(#sha256, expirationBytes));

    // SHA256("pubkey") = "B84B25628F800E36925811AA24AAF28C9F827333D2DF990762B5C3A86EFF7C9B"
    let pubHash : [Nat8] = [0xB8, 0x4B, 0x25, 0x62, 0x8F, 0x80, 0x0E, 0x36, 0x92, 0x58, 0x11, 0xAA, 0x24, 0xAA, 0xF2, 0x8C, 0x9F, 0x82, 0x73, 0x33, 0xD2, 0xDF, 0x99, 0x07, 0x62, 0xB5, 0xC3, 0xA8, 0x6E, 0xFF, 0x7C, 0x9B];
    let pubkeyHash : [Nat8] = Blob.toArray(Sha256.fromArray(#sha256, sessionKey));

    // concat and hash
    let concatenated = Array.flatten([expHash, expirationHash, pubHash, pubkeyHash]);
    let concatHash = Blob.toArray(Sha256.fromArray(#sha256, concatenated));

    // add domain seperator "\x1Aic-request-auth-delegation";
    let domainSeparator : [Nat8] = [0x1A, 0x69, 0x63, 0x2d, 0x72, 0x65, 0x71, 0x75, 0x65, 0x73, 0x74, 0x2d, 0x61, 0x75, 0x74, 0x68, 0x2d, 0x64, 0x65, 0x6c, 0x65, 0x67, 0x61, 0x74, 0x69, 0x6f, 0x6e];
    let unsigned = Array.flatten<Nat8>([domainSeparator, concatHash]);

    let signature = Ed25519.sign(unsigned, identityKeyPair.secretKey);
    let delegation = {
      delegation = {
        pubkey = sessionKey;
        expiration;
        targets = null;
      };
      signature;
    };
    return {
      kind;
      delegations = [delegation];
      userPublicKey = identityKeyPair.publicKey;
      authnMethod;
    };
  };
};
