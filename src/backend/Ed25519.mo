import NACL "mo:tweetnacl";
import Option "mo:base/Option";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Hex "./Hex";

module {
  //let convert = func(x : Text) : [Nat8] = Blob.toArray(Text.encodeUtf8(x));
  let revert = func(r : [Nat8]) : Text = Option.get(Text.decodeUtf8(Blob.fromArray(r)), "");
  type Result<T, E> = Result.Result<T, E>;

  public type KeyPair = { publicKey : [Nat8]; secretKey : [Nat8] };
  public type DB<T> = {
    set : (k : T, v : KeyPair) -> ();
    get : (k : T) -> ?KeyPair;
  };

  public func getKeyPair<T>(map : DB<T>, k : T, createIfNotFound : Bool) : Result<KeyPair, Text> {
    switch (map.get(k)) {
      case (?keys) return #ok(keys);
      case (null) {
        if (not createIfNotFound) return #err("Key not found");
        // TODO!: keyPair is using insecure seed for key generation
        var keys = NACL.SIGN.keyPair(null);
        map.set(k, keys);
        return #ok(keys);
      };
    };
  };

  public func getPubKey<T>(map : DB<T>, k : T) : [Nat8] {
    let #ok(keys) = getKeyPair(map, k, true) else Debug.trap("Key not found");
    keys.publicKey;
  };

  public func sign<T>(data : [Nat8], secretKey : [Nat8]) : [Nat8] {
    if (secretKey.size() != 64) Debug.trap("Invalid key size: expected 64 got" # Nat.toText(secretKey.size()));
    NACL.SIGN.DETACHED.detached(data, secretKey);
  };

  public func verify(data : [Nat8], signature : [Nat8], publicKey : [Nat8]) : Bool {
    NACL.SIGN.DETACHED.verify(data, signature, publicKey);
  };

  public func DERencodePubKey(publicKey : [Nat8]) : [Nat8] {
    if (publicKey.size() != 32) Debug.trap("Unexpected key length: " # Nat.toText(publicKey.size()));

    return Array.flatten<Nat8>([[0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00], publicKey]);

    // DER encoding components for Ed25519
    let derAlgorithmIdentifier : [Nat8] = [
      // SEQUENCE (5 bytes)
      0x30,
      0x05,
      // OID 1.3.101.112 (Ed25519)
      0x06,
      0x03,
      0x2B,
      0x65,
      0x70,
      // NULL
      0x05,
      0x00,
    ];

    // BIT STRING (33 bytes total: 1 padding byte (0x00) + 32-byte key)
    let derBitStringPrefix : [Nat8] = [0x03, 33, 0x00]; // BIT STRING (33 bytes (0x21))

    // Wrap everything in a SEQUENCE
    // 9 byte derAlgorithmIdentifier + 3 byte derBitStringPrefix + 32 byte key;
    let contentSize : Nat8 = 9 + 3 + 32;

    let derSequence : [Nat8] = Array.flatten<Nat8>([
      [0x30 : Nat8, contentSize],
      derAlgorithmIdentifier,
      derBitStringPrefix,
      publicKey,
    ]);

    return derSequence;
  };

};
