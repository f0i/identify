import { print; trap } "mo:base/Debug";
import Ed25519 "../src/backend/Ed25519";

let voidDB = {
  set = func(_k : Text, _v : Ed25519.KeyPair) {};
  get = func(_k : Text) : ?Ed25519.KeyPair { null };
};

print("# ED25519");

print("- generate keys");
let #ok(keys) = Ed25519.getKeyPair(voidDB, "", true) else trap("failed to generate keys");
//print(debug_show (keys));
assert (keys.publicKey.size() == 32);
assert (keys.secretKey.size() == 64);
