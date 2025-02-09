import Sha256 "mo:sha2/Sha256";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Nat8 "mo:base/Nat8";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Result "mo:base/Result";

// Partial implementation of a hash tree with just the functions to generate canister signatures
module {
  type Hash = [Nat8];
  type Result<T, E> = Result.Result<T, E>;
  type Time = Time.Time;

  public type HashTree = {
    #Empty;
    #Fork : (HashTree, HashTree);
    #Labeled : (Blob, HashTree);
    #Leaf : Blob;
    #Pruned : Hash;
  };

  // I only want to insert signatures at /sig/<seed>/<data> and /time/<time>.
  // Order does not matter because I will always return a pruned tree which only contains /time and one element in /sig

  public func addSig(tree : HashTree, seed : Text, hash : Blob) : Result<HashTree, Text> {
    let now = Time.now();
    switch (tree) {
      case (#Fork(#Labeled("sig", _), #Labeled("time", #Leaf(_)))) insertSig(tree, seed, hash, now);
      case (#Empty) initSigTree(seed, hash, now);
      case (_) initSigTree(seed, hash, now); // TODO: handle other cases instead of overwriting
    };
  };

  func insertSig(tree : HashTree, seed : Text, hash : [Nat8], now : Time) : HashTree {
    let #Fork(#Labeled("sig", sig), #Labeled("time", #Leaf(time))) = tree else return #Empty;
    let newSig : HashTree = labeled(seed, #Labeled(Blob.fromArray(hash), #Leaf("")));
    // this is not well formed (not ordered, unbalanced, duplicate), but since the other sigs will be purned, it doesn't matter
    let allSig = #Fork(newSig, sig);
    return #Fork(#Labeled("sig", allSig), #Labeled("time", #Leaf(now)));
  };

  let certKey = [0x6B, 0x63, 0x65, 0x72, 0x74, 0x69, 0x66, 0x69, 0x63, 0x61, 0x74, 0x65]; // "certificate"
  let treeKey = [0x64, 0x74, 0x72, 0x65, 0x65]; // "tree"

  public func encodeCert(tree : HashTree, seed : Text, cert : Blob) : [Nat8] {
    let tagHeader = [0xD9, 0xD9, 0xF7]; // CBOR tag 55799

    let certCBOR = cborBlob(cert);
    let treeCBOR = cbor(tree);

    Array.flatten([
      tagHeader,
      [0xA2], // cbor Map with two key value pairs
      certKey,
      certCBOR,
      treeKey,
      treeCBOR,
    ]);
  };

  public func getPrunedSig(tree : HashTree, seed : Text) : HashTree {
    let #Fork(#Labeled("sig", sig), #Labeled("time", #Leaf(time))) = tree else return #Empty;
    let sigTree = getSig(sig, seed);
    if (sigTree.found) {
      return #Fork(#Labeled("sig", sigTree.tree), #Labeled("time", #Leaf(time)));
    };
    return #Empty;
  };

  func getSig(tree : HashTree, seed : Text) : { found : Bool; tree : HashTree } {
    switch (tree) {
      case (#Empty) return { found = false; tree };
      case (#Fork(a, b)) {
        let subA = getSig(a, seed);
        if (subA.found) {
          let newTree = #Fork(subA.tree, prune(b));
          return { found = true; tree = newTree };
        };
        let subB = getSig(b, seed);
        if (subB.found) {
          let newTree = #Fork(prune(a), subB.tree);
          return { found = true; tree = newTree };
        };
        return { found = false; tree };
      };
      case (#Labeled(l, t)) return { found = (l == seed) };
      case (#Leaf(v)) return { found = false; tree };
      case (#Pruned(h)) return { found = false; tree };
    };
  };

  func initSigTree(seed : Text, Hash : [Nat8], now : Time) : HashTree {
    let allSig : HashTree = labeled(seed, #Labeled(Blob.fromArray(hash), #Leaf("")));
    return #Fork(#Labeled("sig", allSig), #Labeled("time", #Leaf(now)));
  };

  public func labeled(l : Text, tree : HashTree) : HashTree {
    return #Labeled(Text.encodeUtf8(l), tree);
  };

  public func prune(tree : HashTree) : HashTree {
    return #Pruned(hash(tree));
  };

  // ic-hashtree-empty
  let sepEmpty : [Nat8] = [17, 0x69, 0x63, 0x2d, 0x68, 0x61, 0x73, 0x68, 0x74, 0x72, 0x65, 0x65, 0x2d, 0x65, 0x6d, 0x70, 0x74, 0x79];
  // ic-hashtree-fork
  let sepFork : [Nat8] = [16, 0x69, 0x63, 0x2d, 0x68, 0x61, 0x73, 0x68, 0x74, 0x72, 0x65, 0x65, 0x2d, 0x66, 0x6f, 0x72, 0x6b];
  // ic-hashtree-labeled
  let sepLabeled : [Nat8] = [19, 0x69, 0x63, 0x2d, 0x68, 0x61, 0x73, 0x68, 0x74, 0x72, 0x65, 0x65, 0x2d, 0x6c, 0x61, 0x62, 0x65, 0x6c, 0x65, 0x64];
  // ic-hashtree-leaf
  let sepLeaf : [Nat8] = [16, 0x69, 0x63, 0x2d, 0x68, 0x61, 0x73, 0x68, 0x74, 0x72, 0x65, 0x65, 0x2d, 0x6c, 0x65, 0x61, 0x66];

  public func hash(tree : HashTree) : Hash {
    switch (tree) {
      case (#Empty) shaHash(sepEmpty);
      case (#Fork(a, b)) shaHash(Array.flatten([sepFork, hash(a), hash(b)]));
      case (#Labeled(l, t)) shaHash(Array.flatten([sepLabeled, Blob.toArray(l), hash(t)]));
      case (#Leaf(v)) shaHash(Array.flatten([sepLeaf, Blob.toArray(v)]));
      case (#Pruned(h)) h;
    };
  };

  func shaHash(data : [Nat8]) : [Nat8] = Blob.toArray(Sha256.fromArray(#sha256, data));

  func textToBytes(t : Text) : [Nat8] = Blob.toArray(Text.encodeUtf8(t));

  public func cbor(tree : HashTree) : [Nat8] {
    switch (tree) {
      case (#Empty) [0x81, 0];
      case (#Fork(a, b)) Array.flatten<Nat8>([[0x83, 1], cbor(a), cbor(b)]);
      case (#Labeled(l, t)) Array.flatten<Nat8>([[0x83, 2], cborLabel(l), cbor(t)]);
      case (#Leaf(v)) Array.flatten<Nat8>([[0x82, 3], cborBlob(v)]);
      case (#Pruned(h)) Array.flatten<Nat8>([[0x82, 4], cborHash(h)]);
    };
  };

  func cborLabel(l : Text) : [Nat8] {
    cborData(textToBytes(l));
  };

  func cborBlob(blob : Blob) : [Nat8] {
    let data = Blob.toArray(blob);
    cborData(data);
  };

  func cborHash(h : Hash) : [Nat8] {
    cborData(h);
  };

  func cborData(data : [Nat8]) : [Nat8] {
    let n = Array.size(data);
    let head : [Nat8] = if (n < 24) {
      // For small blobs, 0x40 + length
      [0x40 + Nat8.fromNat(n)];
    } else if (n < 256) {
      // 0x58 indicates one additional byte for length
      [0x58, Nat8.fromNat(n)];
    } else if (n < 65536) {
      // 0x59 indicates two additional bytes for length
      let high = Nat8.fromNat(n / 256);
      let low = Nat8.fromNat(n % 256);
      [0x59, high, low];
    } else {
      // larger lengths could use 0x5A for 4-byte length, but in our case this is unlikeley to happen
      Debug.trap("Blob too large to encode");
    };
    return Array.flatten([head, data]);
  };

};
