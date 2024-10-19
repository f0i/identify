import { print; trap } "mo:base/Debug";
import Ed25519 "../src/backend/Ed25519";

let voidDB = {
  set = func(_k : Text, _v : Ed25519.KeyPair) {};
  get = func(_k : Text) : ?Ed25519.KeyPair { null };
};

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
