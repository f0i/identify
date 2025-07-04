import { print; trap } "mo:base/Debug";
import Debug "mo:base/Debug";
import HashTree "../src/backend/HashTree";
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

let cbor : [Nat8] = [
0x83, 0x01, 0x83, 0x01, 0x83, 0x02, 0x41, 0x61, 0x83, 0x01, 0x83, 0x01, 0x83, 0x02, 0x41, 0x78, 0x82, 0x03, 0x45, 0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x81, 0x00, 0x83, 0x02, 0x41, 0x79, 0x82, 0x03, 0x45, 0x77, 0x6f, 0x72, 0x6c, 0x64, 0x83, 0x02, 0x41, 0x62, 0x82, 0x03, 0x44, 0x67, 0x6f, 0x6f, 0x64, 0x83, 0x01, 0x83, 0x02, 0x41, 0x63, 0x81, 0x00, 0x83, 0x02, 0x41, 0x64, 0x82, 0x03, 0x47, 0x6d, 0x6f, 0x72, 0x6e, 0x69, 0x6e, 0x67
];
let hash : [Nat8] = [
0xeb, 0x5c, 0x5b, 0x21, 0x95, 0xe6, 0x2d, 0x99, 0x6b, 0x84, 0xc9, 0xbc, 0xc8, 0x25, 0x9d, 0x19, 0xa8, 0x37, 0x86, 0xa2, 0xf5, 0x9e, 0x08, 0x78, 0xce, 0xc8, 0x4c, 0x81, 0x1f, 0x66, 0x9a, 0xa0
];

if (HashTree.cbor(tree) != cbor) trap("could not encode full tree");
if (HashTree.hash(tree) != hash) trap("could not calculate hash of full tree");

print("- sig pruning");

let sigTree = HashTree.addSig(#Empty, "test", [1,2,3,4], 1234567890);
let pruned1 = HashTree.getPrunedSigTree(sigTree, "test");
if (pruned1 != sigTree) trap("should not prune anything from tree with only one signature");

let sigTree2 = HashTree.addSig(sigTree, "asdf", [4,3,2,1], 12345678920);
let hash2 = HashTree.hash(sigTree2);


let expectedHash2: [Nat8] = [140, 30, 35, 152, 250, 235, 73, 46, 245, 79, 212, 59, 255, 84, 220, 240, 101, 49, 244, 169, 151, 95, 10, 132, 240, 41, 15, 120, 171, 107, 206, 221];

if (hash2 != expectedHash2) trap("unexpected hash for tree with two signatures");

let pruned2 = HashTree.getPrunedSigTree(sigTree2, "test");
if (HashTree.hash(pruned2) != hash2) trap("hash must not change when pruning");

print("- sig encoding");

let cert = [11,22,33,44,55,66];

let cbor2 = HashTree.cbor(pruned2);


Debug.print(debug_show cbor2);

