import Result "mo:base/Result";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Base64 "Base64";
import { JSON } "mo:serde";
module {

  public type PubKey = {
    e : Nat;
    n : Nat;
    kid : Text;
    use : Text;
    alg : Text;
    kty : Text;
  };

  // Padding and ASN.1 encodeing for RS256 signatures
  // This should always be the same as long as RS256 is used
  let RS256Padding : [Nat8] = [1, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 0, 48, 49, 48, 13, 6, 9, 96, 134, 72, 1, 101, 3, 4, 2, 1, 5, 0, 4, 32];

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
    let sigArr = switch (Base64.decode(signature)) {
      case (#ok val) val;
      case (#err err) return #err("couldn't decode signature: " # err);
    };

    let sig = bytesToNat(sigArr);

    var decrypted = modExp(sig, pubKey.e, pubKey.n);

    let decBuf = Buffer.Buffer<Nat8>(3);
    while (decrypted > 0) {
      let val = Nat8.fromIntWrap(decrypted);
      decrypted /= 0x100;
      decBuf.add(val);
    };
    Buffer.reverse(decBuf);
    assert (RS256Padding.size() == (255 - 32 : Nat));
    for (i in Iter.range(0, 255 - 32 - 1)) {
      if (decBuf.get(i) != RS256Padding[i]) return #err("invalid padding value at index " # Nat.toText(i) # ": " # Nat8.toText(decBuf.get(i)));
    };

    let buf2 = Buffer.subBuffer(decBuf, 255 - 32 : Nat, 32);
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

  /// Extract public keys from JSON data formated `{"keys": [{"kid": ...}, ...]}`
  /// This is also the format returned by https://www.googleapis.com/oauth2/v3/certs
  public func pubKeysFromJSON(keysJSON : Text) : Result.Result<[PubKey], Text> {
    // Intermediate type with base64 encoded key data
    type Key64 = {
      e : Text;
      n : Text;
      kid : Text;
      use : Text;
      alg : Text;
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
        use = key.use;
        alg = key.alg;
        kty = key.kty;
      });
    };

    return #ok(Buffer.toArray(keys));
  };
};
