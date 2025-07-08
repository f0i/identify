import { print; trap } "mo:base/Debug";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import HashTree "../src/backend/HashTree";
import Hex "../src/backend/Hex";
type HashTree = HashTree.HashTree;

print("# HashTree");

/*
Example from IC interface spec
https://internetcomputer.org/docs/current/references/ic-interface-spec#example

─┬─┬╴"a" ─┬─┬╴"x" ─╴"hello"
 │ │      │ └╴Empty
 │ │      └╴  "y" ─╴"world"
 │ └╴"b" ──╴"good"
 └─┬╴"c" ──╴Empty
   └╴"d" ──╴"morning"

8301830183024161830183018302417882034568656c6c6f810083024179820345776f726c6483024162820344676f6f648301830241638100830241648203476d6f726e696e67

eb5c5b2195e62d996b84c9bcc8259d19a83786a2f59e0878cec84c811f669aa0
*/

print("- encode #Empty");
if (HashTree.cbor(#Empty) != [0x81, 0]) trap("could not encode empty tree");

print("- encode full tree");
let x : HashTree = #Labeled("x", #Leaf("hello"));
let y : HashTree = #Labeled("y", #Leaf("world"));
let b : HashTree = #Labeled("b", #Leaf("good"));
let c : HashTree = #Labeled("c", #Empty);
let d : HashTree = #Labeled("d", #Leaf("morning"));

let a : HashTree = #Labeled("a", #Fork(#Fork(x, #Empty), y));
let tree : HashTree = #Fork(#Fork(a, b), #Fork(c, d));

let cbor : [Nat8] = Hex.toArrayUnsafe("8301830183024161830183018302417882034568656c6c6f810083024179820345776f726c6483024162820344676f6f648301830241638100830241648203476d6f726e696e67");
let hash : [Nat8] = Hex.toArrayUnsafe("eb5c5b2195e62d996b84c9bcc8259d19a83786a2f59e0878cec84c811f669aa0");

if (HashTree.cbor(tree) != cbor) trap("could not encode full tree");
if (HashTree.hash(tree) != hash) trap("could not calculate hash of full tree");

print("- sig pruning");

var sigTree = HashTree.addSig(#Empty, "test", [1, 2, 3, 4], 1234567890);
let pruned1 = HashTree.getPrunedSigTree(sigTree, "test");
if (pruned1 != sigTree) trap("should not prune anything from tree with only one signature");

let sigTree2 = HashTree.addSig(sigTree, "asdf", [4, 3, 2, 1], 12345678920);
let hash2 = HashTree.hash(sigTree2);

let expectedHash2 : [Nat8] = Hex.toArrayUnsafe("8c1e2398faeb492ef54fd43bff54dcf06531f4a9975f0a84f0290f78ab6bcedd");

if (hash2 != expectedHash2) trap("unexpected hash for tree with two signatures");

let pruned2 = HashTree.getPrunedSigTree(sigTree2, "test");
if (HashTree.hash(pruned2) != hash2) trap("hash must not change when pruning");

print("- sig encoding");

let cert = Blob.fromArray([11, 22, 33, 44, 55, 66]);

let cbor2 = HashTree.cbor(pruned2);

if (cbor2 != Hex.toArrayUnsafe("8301830243736967830182045820b3959f2f87c06a6bef1dffa14fb5332c9992c5b84b28b2503d2c0ddf567f46aa830244746573748302440102030482034083024474696d6582034800000002dfdc1c48")) trap("unexpected cbor encoding of pruned sig tree");

let sig = HashTree.getSignature(pruned2, "test", cert);

if (sig != Hex.toArrayUnsafe("d9d9f7a26b6365727469666963617465460b16212c374264747265658301830243736967830182045820b3959f2f87c06a6bef1dffa14fb5332c9992c5b84b28b2503d2c0ddf567f46aa830244746573748302440102030482034083024474696d6582034800000002dfdc1c48")) trap("unexpected signature " # Hex.toText(sig));

print("- add multiple signatures");

sigTree := #Empty;
sigTree := HashTree.addSig(sigTree, "test1", [1, 1, 1], 10);
sigTree := HashTree.addSig(sigTree, "test2", [2, 2, 2], 20);
sigTree := HashTree.addSig(sigTree, "test3", [3, 3, 3], 30);
sigTree := HashTree.addSig(sigTree, "test4", [4, 4, 4], 40);
sigTree := HashTree.addSig(sigTree, "test5", [5, 5, 5], 50);

let expectedHash3 : [Nat8] = Hex.toArrayUnsafe("b00eb7f58eb0df3c9200b0f4c870124817f9287db12c0c7cdd2349e29145b26d");
if (HashTree.hash(sigTree) != expectedHash3) {
  trap("unexpected tree after adding multiple signatures:\n" # HashTree.toText(sigTree));
};

print("- remove multiple signatures");
// Keep 3 signatures
sigTree := HashTree.removeSigs(sigTree, 3);

let expectedHash4 : [Nat8] = Hex.toArrayUnsafe("1618f2d54bbdf382bdf8901e0f8bafcab777a2fd12279e58359cdaefcb57f9b7");
if (HashTree.hash(sigTree) != expectedHash4) {
  trap("unexpected tree after keeping last 3 signatures:\n" # HashTree.toText(sigTree));
};
// Keep 2 signatures
sigTree := HashTree.removeSigs(sigTree, 2);

let expectedHash5 : [Nat8] = Hex.toArrayUnsafe("de62c10487cfb524543bf229741a7c9bb8bbe7f9bc9f5d6ce4bf566c25c025a1");
if (HashTree.hash(sigTree) != expectedHash5) {
  trap("unexpected tree after keeping last 2 signatures:\n" # HashTree.toText(sigTree));
};
