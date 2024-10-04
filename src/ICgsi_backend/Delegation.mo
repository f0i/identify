import Ed25519 "Ed25519";
import ULEB128 "ULEB128";
import Int "mo:base/Int";
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

    let signature = [];
    let delegation = {
      delegation = {
        pubkey = sessionKey;
        expiration;
      };
      signature;
    };
    return {
      kind;
      delegations = [];
      userPublicKey = identityKeyPair.publicKey;
      authnMethod;
    };
  };
};
