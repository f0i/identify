import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Base64 "Base64";
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
    let sigArr = switch (Base64.URLEncoding.decodeText(signature)) {
      case (#ok val) val;
      case (#err err) Debug.trap("couldn't decode signature: " # err);
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

};
