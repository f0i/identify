import NACL "mo:tweetnacl";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Sha256 "mo:sha2/Sha256";

module {
  type Result<T, E> = Result.Result<T, E>;

  public type KeyPair = { publicKey : [Nat8]; secretKey : [Nat8] };

  public func generateKeyPair() : async KeyPair {
    return await NACL.SIGN.asyncKeyPair(null);
  };
  public func generateInsecureKeyPair() : KeyPair = NACL.SIGN.keyPair(null);

  public func sign<T>(data : [Nat8], secretKey : [Nat8]) : [Nat8] {
    if (secretKey.size() != 64) Debug.trap("Invalid key size: expected 64 got" # Nat.toText(secretKey.size()));
    NACL.SIGN.DETACHED.detached(data, secretKey);
  };

  public func verify(data : [Nat8], signature : [Nat8], publicKey : [Nat8]) : Bool {
    NACL.SIGN.DETACHED.verify(data, signature, publicKey);
  };

  public func DERencodePubKey(publicKey : [Nat8]) : [Nat8] {
    if (publicKey.size() != 32) Debug.trap("Unexpected key length: " # Nat.toText(publicKey.size()));

    return Array.flatten<Nat8>([
      [
        0x30, // start sequence
        0x2a, // total length
        0x30,
        0x05, // sequence
        0x06,
        0x03,
        0x2b,
        0x65,
        0x70, // ed25519
        0x03, // start bit string
        0x21, // length key + 1byte padding (33)
        0x00, // padding
      ],
      publicKey,
    ]);
  };

  public func toPrincipal(publicKey : [Nat8]) : Principal {
    let hash = Sha256.fromArray(#sha224, DERencodePubKey(publicKey));
    let bytes = Blob.toArray(hash);
    let allBytes = Array.flatten<Nat8>([bytes, [0x02]]);

    Principal.fromBlob(Blob.fromArray(allBytes));
  };

};
