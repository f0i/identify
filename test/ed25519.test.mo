import { print; trap } "mo:base/Debug";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Ed25519 "../src/backend/Ed25519";

print("# ED25519");

print("- generate keys");
let keys1 = Ed25519.generateInsecureKeyPair();
let keys2 = Ed25519.generateInsecureKeyPair();
let keys3 = await Ed25519.generateKeyPair();
let keys4 = await Ed25519.generateKeyPair();
//print(debug_show (keys));
assert (keys1.publicKey.size() == 32);
assert (keys1.secretKey.size() == 64);
assert (keys1 == keys2); // This is bad but expected
assert (keys2 != keys3);
assert (keys2 != keys4);
assert (keys3 != keys4);

let pubkey : [Nat8] = [153, 30, 220, 240, 152, 20, 109, 84, 56, 102, 103, 119, 109, 61, 46, 238, 153, 4, 54, 24, 231, 111, 117, 61, 78, 43, 206, 117, 131, 107, 118, 99];
if (pubkey.size() != 32) trap("invalid pubkey size " # Nat.toText(pubkey.size()));
let p = Ed25519.toPrincipal(pubkey);
let pRef = Principal.fromText("c3iil-eef26-be4fg-cxkyz-gmh6i-jeecn-2modf-fi2ht-r43ks-3xaez-bae");
if (p != pRef) trap("invalid principal " # Principal.toText(p));
