import Result "mo:base/Result";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Base64 "Base64";
import { JSON } "mo:serde";
import Text "mo:core/Text";
import Runtime "mo:core/Runtime";
import Option "mo:core/Option";
import Debug "mo:core/Debug";

module {

  public type PubKey = {
    e : Nat;
    n : Nat;
    kid : Text;
    use : Text;
    alg : Text;
    kty : Text;
  };

  // Padding and ASN.1 encoding for RS256 signatures
  // This should always be the same as long as RS256 is used
  let RS256Padding : [Nat8] = [0, 1, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 0, 48, 49, 48, 13, 6, 9, 96, 134, 72, 1, 101, 3, 4, 2, 1, 5, 0, 4, 32];

  func modExp(base : Nat, exp : Nat, mod : Nat) : Nat {
    var result = 1;
    var power = base;
    var exponent = exp;

    while (exponent > 0) {
      if (exponent % 2 == 1) {
        result := (result * power) % mod;
      };
      exponent := exponent / 2;
      power := (power * power) % mod;
    };
    return result;
  };

  func bytesToNat(bytes : [Nat8]) : Nat {
    return Array.foldLeft<Nat8, Nat>(
      bytes,
      0,
      func(acc : Nat, val : Nat8) : Nat { return acc * 0x100 + Nat8.toNat(val) },
    );
  };

  func decryptSig(signature : Text, pubKey : PubKey) : Result.Result<[Nat8], Text> {
    Debug.print("Decrypt signature: " # signature);
    let sigArr = switch (Base64.decode(signature)) {
      case (#ok val) val;
      case (#err err) return #err("couldn't decode signature: " # err);
    };

    let sig = bytesToNat(sigArr);

    var decrypted = modExp(sig, pubKey.e, pubKey.n);

    let decBuf = Buffer.Buffer<Nat8>(512);
    while (decrypted > 0) {
      let val = Nat8.fromIntWrap(decrypted);
      decrypted /= 0x100;
      decBuf.add(val);
    };
    decBuf.add(0);
    Buffer.reverse(decBuf);

    // Check padding
    assert (RS256Padding.size() == (256 - 32 : Nat));
    if (decBuf.size() == 256) {
      for (i in Iter.range(2, 256 - 32 - 1)) {
        if (decBuf.get(i) != RS256Padding[i]) {
          return #err("invalid padding value at index " # Nat.toText(i) # ": " # Nat8.toText(decBuf.get(i)));
        };
      };
    } else if (decBuf.size() == 512) {
      if (decBuf.get(0) != 0) return #err("invalid padding value at index 0: " # Nat8.toText(decBuf.get(0)));
      if (decBuf.get(1) != 1) return #err("invalid padding value at index 1: " # Nat8.toText(decBuf.get(1)));
      for (i in Iter.range(2, 256 + 2)) {
        if (decBuf.get(i) != 255) {
          return #err("invalid padding value at index " # Nat.toText(i) # ": " # Nat8.toText(decBuf.get(i + 256)));
        };
      };
      for (i in Iter.range(2, 256 - 32 - 1)) {
        if (decBuf.get(i + 256) != RS256Padding[i]) {
          return #err("invalid padding value at index " # Nat.toText(i) # ": " # Nat8.toText(decBuf.get(i + 256)));
        };
      };
    } else {
      return #err("invalid signature size " # Nat.toText(decBuf.size()));
    };

    let buf2 = Buffer.subBuffer(decBuf, decBuf.size() - 32 : Nat, 32);
    assert (buf2.size() == 32);

    return #ok(Buffer.toArray<Nat8>(buf2));
  };

  public func verifySig(dataHash : Blob, signature : Text, key : PubKey) : Result.Result<(), Text> {
    let decrypted = switch (decryptSig(signature, key)) {
      case (#ok data) data;
      case (#err err) return #err("invalid signature: " # err);
    };

    let dataNat8 = Blob.toArray(dataHash);

    if (decrypted != dataNat8) {
      return #err("decrypted hash does not match content hash");
    } else {
      return #ok;
    };
  };

  /// Extract public keys from JSON data formatted `{"keys": [{"kid": ...}, ...]}`
  /// This is also the format returned by https://www.googleapis.com/oauth2/v3/certs
  public func pubKeysFromJSON(keysJSON : Text) : Result.Result<[PubKey], Text> {
    // Intermediate type with base64 encoded key data
    type Key64 = {
      e : Text;
      n : Text;
      kid : Text;
      use : ?Text;
      alg : ?Text;
      kty : Text;
    };
    type KeyData = {
      keys : [Key64];
    };
    let dataBlob = switch (JSON.fromText(keysJSON, null)) {
      case (#ok data) data;
      case (#err err) return #err("could not parse keys: " # err);
    };
    let ?keyData : ?KeyData = from_candid (dataBlob) else return #err("missing fields in " # keysJSON);

    let keys = Buffer.Buffer<PubKey>(keyData.keys.size());
    for (key in keyData.keys.vals()) {
      let eBytes = switch (Base64.decode(key.e)) {
        case (#ok val) val;
        case (#err err) return #err("couldn't decode n of public key" # err);
      };
      let e = bytesToNat(eBytes);
      let nBytes = switch (Base64.decode(key.n)) {
        case (#ok val) val;
        case (#err err) return #err("couldn't decode e of public key: " # err);
      };
      let n = bytesToNat(nBytes);

      keys.add({
        e;
        n;
        kid = key.kid;
        use = Option.get(key.use, "sig");
        alg = Option.get(key.alg, "RS256");
        kty = key.kty;
      });
    };

    return #ok(Buffer.toArray(keys));
  };

  /// Encode to custom key serialization format.
  /// Only use with the same version of serialize and deserialize functions! (e.g. in transform step during http outcalls)
  /// The format is not guaranteed to be stable, mixing different versions might result in invalid keys.
  /// Do NOT use for persisting keys in stable memory!
  public func serializeKey(key : PubKey) : Text {
    key.alg # "," # key.kid # "," # key.use # "," # key.kty # "," # Nat.toText(key.e) # "," # Nat.toText(key.n);
  };

  /// Encode to custom key serialization format.
  /// Only use with the same version of serialize and deserialize functions! (e.g. in transform step during http outcalls)
  /// The format is not guaranteed to be stable, mixing different versions might result in invalid keys.
  /// Do NOT use for persisting keys in stable memory!
  public func serializeKeys(keys : [PubKey]) : Text {
    Array.map(keys, serializeKey)
    |> Array.sort(_, Text.compare)
    |> Text.join("\n", _.vals());
  };

  /// Decode to custom key serialization format.
  /// Only use with the same version of serialize and deserialize functions! (e.g. in transform step during http outcalls)
  /// The format is not guaranteed to be stable, mixing different versions might result in invalid keys.
  /// Do NOT use for persisting keys in stable memory!
  public func deserializeKey(serialized : Text) : PubKey {
    let parts = Text.split(serialized, #char ',') |> Iter.toArray(_);
    if (parts.size() != 6) Runtime.trap("Invalid serialized key");
    let ?e = Nat.fromText(parts[4]) else Runtime.trap("Invalid value of e in RSA key");
    let ?n = Nat.fromText(parts[5]) else Runtime.trap("Invalid value of n in RSA key");
    return {
      alg = parts[0];
      kid = parts[1];
      use = parts[2];
      kty = parts[3];
      e;
      n;
    };
  };

  /// Decode to custom key serialization format.
  /// Only use with the same version of serialize and deserialize functions! (e.g. in transform step during http outcalls)
  /// The format is not guaranteed to be stable, mixing different versions might result in invalid keys.
  /// Do NOT use for persisting keys in stable memory!
  public func deserializeKeys(serialized : Text) : [PubKey] {
    Text.split(serialized, #char '\n')
    |> Iter.map(_, deserializeKey)
    |> Iter.toArray(_);
  };

};
