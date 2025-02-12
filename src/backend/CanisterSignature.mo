import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Sha256 "mo:sha2/Sha256";
module {

  public func DERencodePubKey(canister : Principal, seed : Blob) : [Nat8] {
    let canisterId = Blob.toArray(Principal.toBlob(canister));
    assert Array.size(canisterId) < (255 - 17 : Nat);
    let idSize : Nat8 = Nat8.fromIntWrap(Array.size(canisterId));
    let rawPk : [Nat8] = Array.flatten<Nat8>([[idSize], canisterId, Blob.toArray(seed)]);
    let rawPkSize : Nat8 = Nat8.fromIntWrap(Array.size(rawPk));
    let totalSize : Nat8 = 17 + rawPkSize;

    return Array.flatten<Nat8>([
      [
        0x30, // start sequence
        totalSize, // total length 17+keylength
        0x30,
        0x0C,
        0x06,
        0x0A,
        0x2B,
        0x06,
        0x01,
        0x04,
        0x01,
        0x83,
        0xB8,
        0x43,
        0x01,
        0x02, // canister sig OID
        0x03, // start bit string
        rawPkSize + 1, // length key + 1byte padding
        0x00, // padding
      ],
      rawPk,
    ]);
  };

  public func toPrincipal(canister : Principal, seed : Blob) : Principal {
    // TODO?: pass in DER encoded key to avoid re-encoding of the key within one request
    let hash = Sha256.fromArray(#sha224, DERencodePubKey(canister, seed));
    let bytes = Blob.toArray(hash);
    let allBytes = Array.flatten<Nat8>([bytes, [0x02]]);

    Principal.fromBlob(Blob.fromArray(allBytes));
  };

};
