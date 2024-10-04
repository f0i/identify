import NACL "mo:tweetnacl";
import Option "mo:base/Option";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";
import Hex "./Hex";

module {
  let convert = func(x : Text) : [Nat8] = Blob.toArray(Text.encodeUtf8(x));
  let revert = func(r : [Nat8]) : Text = Option.get(Text.decodeUtf8(Blob.fromArray(r)), "");

  public type KeyPair = { publicKey : [Nat8]; secretKey : [Nat8] };
  public type DB<T> = {
    set : (k : T, v : KeyPair) -> ();
    get : (k : T) -> ?KeyPair;
  };

  func getKeyPair<T>(map : DB<T>, k : T) : KeyPair {
    switch (map.get(k)) {
      case (?keys) return keys;
      case (null) {
        // TODO!: keyPair is using insecure seed for key generation
        var keys = NACL.SIGN.keyPair(null);
        map.set(k, keys);
        return keys;
      };
    };
  };

  public func getPubKey<T>(map : DB<T>, k : T) : [Nat8] {
    getKeyPair(map, k).publicKey;
  };

  public func sign<T>(map : DB<T>, k : T, data : Text) : Text {
    var keyPair = getKeyPair(map, k);
    let { publicKey : [Nat8]; secretKey : [Nat8] } = keyPair;

    let rs = NACL.SIGN.sign(convert(data), secretKey);
    Hex.toText(rs) # "  " # Hex.toText(publicKey);
  };

  public shared func signVerify(msg : Text, publicKey : Text) : async (Text, Text) {
    let rs = NACL.SIGN.open(Hex.toArrayUnsafe(msg), Hex.toArrayUnsafe(publicKey));
    switch (rs) {
      case null ("", "");
      case (?r) (Hex.toText(r), revert(r));
    };
  };

  public func DERencodeED25519PubKey(publicKey : [Nat8]) : [Nat8] {
    assert (publicKey.size() == 32); // Public key must be 32 bytes
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
