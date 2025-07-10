import Sha256 "mo:sha2/Sha256";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Nat8 "mo:base/Nat8";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Nat64 "mo:base/Nat64";
import Array "mo:new-base/Array";
import Hex "Hex";

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

  public func toText(tree : HashTree) : Text {
    toTextIndent(tree, 0) # "\nroot hash: " # Hex.toText(hash(tree));
  };

  public func toTextIndent(tree : HashTree, indent : Nat) : Text {
    let indentStr = "\n" # Text.join("", Array.repeat<Text>(" ", indent).vals());
    let content = switch (tree) {
      case (#Empty) "Empty";
      case (#Fork(a, b)) indentStr # "Fork(" # toTextIndent(a, indent + 1) # ", " # toTextIndent(b, indent + 1) # indentStr # ")";
      case (#Labeled(l, t)) "Labeled(" # Hex.toText(Blob.toArray(l)) # "," # toTextIndent(t, indent + 1) # ")";
      case (#Leaf(v)) "Leaf(" # Hex.toText(Blob.toArray(v)) # ")";
      case (#Pruned(h)) "Pruned(" # Hex.toText(h) # ")";
    };
    return content;
  };

  // I only want to insert signatures at /sig/<seed>/<data> and /time/<time>.
  // Order does not matter because I will always return a pruned tree which only contains /time and one element in /sig
  public func addSig(tree : HashTree, seed : Blob, hash : [Nat8], now : Time) : HashTree {
    switch (tree) {
      case (#Fork(#Labeled("sig", _), #Labeled("time", #Leaf(_)))) insertSig(tree, seed, hash, now);
      case (#Empty) initSigTree(seed, hash, now);
      case (_) {
        Debug.print("Unexpected tree format: " # debug_show tree);
        initSigTree(seed, hash, now); // TODO: handle other cases instead of overwriting
      };
    };
  };

  /// Insert a signature into the tree.
  /// The current version does not guarantee a well formed tree!
  func insertSig(tree : HashTree, seed : Blob, hash : [Nat8], now : Time) : HashTree {
    let #Fork(#Labeled("sig", sig), #Labeled("time", #Leaf(_time))) = tree else return #Empty;
    let newSig : HashTree = labeled(seed, #Labeled(Blob.fromArray(hash), #Leaf("")));
    // this is not well formed (not ordered, unbalanced, duplicate), but since the other sigs will be purned, it doesn't matter
    let allSig = #Fork(newSig, sig);
    return #Fork(#Labeled("sig", allSig), #Labeled("time", #Leaf(timeToBytes(now))));
  };

  public func removeSigs(tree : HashTree, depth : Nat) : HashTree {
    // check format of the tree
    let #Fork(#Labeled("sig", sig), #Labeled("time", #Leaf(_time))) = tree else return #Empty;
    return #Fork(#Labeled("sig", keepDepth(sig, depth)), #Labeled("time", #Leaf(_time)));
  };

  func keepDepth(tree : HashTree, depth : Nat) : HashTree {
    switch (tree) {
      case (#Empty) return #Empty;
      case (#Fork(a, b)) if (depth == 0) return #Empty else return #Fork(keepDepth(a, depth - 1), keepDepth(b, depth - 1));
      case (#Labeled(l, t)) return #Labeled(l, keepDepth(t, depth));
      case (#Leaf(v)) return #Leaf(v);
      case (#Pruned(h)) return #Pruned(h);
    };
  };

  let certKey : [Nat8] = [0x6B, 0x63, 0x65, 0x72, 0x74, 0x69, 0x66, 0x69, 0x63, 0x61, 0x74, 0x65]; // "certificate"
  let treeKey : [Nat8] = [0x64, 0x74, 0x72, 0x65, 0x65]; // "tree"

  /// Get a cbor encoded signature
  /// Traps if seed is not in the hashtree
  public func getSignature(tree : HashTree, seed : Blob, cert : Blob) : [Nat8] {
    let tagHeader : [Nat8] = [0xD9, 0xD9, 0xF7]; // CBOR tag 55799

    let certCBOR = cborBlob(cert);
    let prunedTree = getPrunedSigTree(tree, seed);
    // fail if seed was not found
    if (prunedTree == #Empty) Debug.trap("Internal error: could not find any signature for this user.");
    let treeCBOR = cbor(prunedTree);

    Array.flatten<Nat8>([
      tagHeader,
      [0xA2], // cbor Map with two key value pairs
      certKey,
      certCBOR,
      treeKey,
      treeCBOR,
    ]);
  };

  public func getPrunedSigTree(tree : HashTree, seed : Blob) : HashTree {
    let #Fork(#Labeled("sig", sig), #Labeled("time", #Leaf(time))) = tree else return #Empty;
    let sigTree = getSig(sig, seed);
    if (sigTree.found) {
      return #Fork(#Labeled("sig", sigTree.tree), #Labeled("time", #Leaf(time)));
    };
    return #Empty;
  };

  func getSig(tree : HashTree, seed : Blob) : { found : Bool; tree : HashTree } {
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
      case (#Labeled(l, _t)) return { found = (l == seed); tree };
      case (#Leaf(_v)) return { found = false; tree };
      case (#Pruned(_h)) return { found = false; tree };
    };
  };

  func initSigTree(seed : Blob, hash : [Nat8], now : Time) : HashTree {
    let allSig : HashTree = labeled(seed, #Labeled(Blob.fromArray(hash), #Leaf("")));
    return #Fork(#Labeled("sig", allSig), #Labeled("time", #Leaf(timeToBytes(now))));
  };

  public func labeled(l : Blob, tree : HashTree) : HashTree {
    return #Labeled(l, tree);
  };

  public func labeledText(l : Text, tree : HashTree) : HashTree {
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

  func timeToBytes(t : Time) : Blob {
    assert t > 0;
    let n = Nat64.fromIntWrap(t);
    func toNat8(x : Nat64) : Nat8 = Nat8.fromNat(Nat64.toNat(x));

    // TODO: update to use explodeNat64
    let bytes : [Nat8] = [
      toNat8((n >> 56) & 0xFF),
      toNat8((n >> 48) & 0xFF),
      toNat8((n >> 40) & 0xFF),
      toNat8((n >> 32) & 0xFF),
      toNat8((n >> 24) & 0xFF),
      toNat8((n >> 16) & 0xFF),
      toNat8((n >> 8) & 0xFF),
      toNat8(n & 0xFF),
    ];
    return Blob.fromArray(bytes);
  };

  public func cbor(tree : HashTree) : [Nat8] {
    switch (tree) {
      case (#Empty) [0x81, 0];
      case (#Fork(a, b)) Array.flatten<Nat8>([[0x83, 1], cbor(a), cbor(b)]);
      case (#Labeled(l, t)) Array.flatten<Nat8>([[0x83, 2], cborBlob(l), cbor(t)]);
      case (#Leaf(v)) Array.flatten<Nat8>([[0x82, 3], cborBlob(v)]);
      case (#Pruned(h)) Array.flatten<Nat8>([[0x82, 4], cborHash(h)]);
    };
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
