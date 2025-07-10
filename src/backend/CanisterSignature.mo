import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Debug "mo:base/Debug";
import Sha256 "mo:sha2/Sha256";
import Queue "mo:new-base/Queue";
import Time "mo:new-base/Time";
import Text "mo:new-base/Text";
import Option "mo:new-base/Option";
import CertifiedData "mo:new-base/CertifiedData";
import { trap } "mo:new-base/Runtime";
import HashTree "HashTree";
import Delegation "Delegation";
import Hex "Hex";
module {

  type Time = Time.Time;
  type Duration = Time.Duration;
  type HashTree = HashTree.HashTree;

  public type AuthResponse = Delegation.AuthResponse;

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
    pubKeyToPrincipal(DERencodePubKey(canister, seed));
  };

  public func pubKeyToPrincipal(pubKey : [Nat8]) : Principal {
    let hash = Sha256.fromArray(#sha224, pubKey);
    let bytes = Blob.toArray(hash);
    let allBytes = Array.flatten<Nat8>([bytes, [0x02]]);

    Principal.fromBlob(Blob.fromArray(allBytes));
  };

  func shaHashTextToBlob(data : Text) : Blob = Sha256.fromBlob(#sha256, Text.encodeUtf8(data));

  /// Generate a seed and it's hash for a given origin and userId.
  public func encodeSeed(userId : Text, origin : Text) : {
    seed : Blob;
    hashedSeed : Blob;
  } {
    let seed = shaHashTextToBlob(userId # " " # origin);
    let hashedSeed = Sha256.fromBlob(#sha256, seed);
    return { seed; hashedSeed };
  };

  /// Add a signature to the sigTree and store its hash in certified data.
  /// The signature can be requested by getDelegation in a query call.
  public func prepareDelegation(store : SignatureStore, userId : Text, origin : Text, sessionKey : [Nat8], now : Time, timePerLogin : Duration, expireAt : Time, targets : ?[Principal]) : [Nat8] {

    let hash = Delegation.getUnsignedHash(sessionKey, expireAt, targets);
    let { seed; hashedSeed } = encodeSeed(userId, origin);

    // Remove old signatures from sigTree
    while (Option.get(Queue.peekFront(store.sigExpQueue), now) < (now - Time.toNanoseconds(timePerLogin))) {
      ignore Queue.popFront(store.sigExpQueue);
    };
    store.sigTree := HashTree.removeSigs(store.sigTree, Queue.size(store.sigExpQueue));

    // Add signature to the sigTree
    store.sigTree := HashTree.addSig(store.sigTree, hashedSeed, hash, now);
    Queue.pushBack<Time>(store.sigExpQueue, now);

    // Store in certified data
    CertifiedData.set(Blob.fromArray(HashTree.hash(store.sigTree)));

    return DERencodePubKey(store.canister, seed);
  };

  /// This function returns the signature for a delegation created with prepareDelegation
  /// Traps if delegation is not prepared for this userId/origin
  public func getDelegation(store : SignatureStore, userId : Text, origin : Text, sessionKey : [Nat8], expireAt : Time, targets : ?[Principal]) : AuthResponse {
    let ?cert = CertifiedData.getCertificate() else trap("Certificate only available in query calls");

    let { seed; hashedSeed } = encodeSeed(userId, origin);
    let pubKey = DERencodePubKey(store.canister, seed);

    //sign delegation
    let signature = HashTree.getSignature(store.sigTree, hashedSeed, cert);
    let authResponse = Delegation.getDelegationExternalSig(sessionKey, pubKey, signature, expireAt, targets);

    return authResponse;
  };

  type SignatureStore = {
    var sigTree : HashTree;
    sigExpQueue : Queue.Queue<Time>;
    canister : Principal;
  };

  public func newStore(canister : Principal) : SignatureStore {
    {
      var sigTree = #Empty;
      sigExpQueue = Queue.empty<Time>();
      canister;
    };
  };

};
