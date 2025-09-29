import { print } "mo:core/Debug";
import { trap } "mo:core/Runtime";
import RSA "../src/backend/RSA";

// data fetched from
// https://www.googleapis.com/oauth2/v3/certs
// from different locations using globalping
// (see test/keys/fetch.sh)
import { data } "./keys/certs"

print("# Http key fetching");
print("- parse first RSA keys");

let keys = switch (RSA.pubKeysFromJSON(data[0])) {
  case (#err err) trap("failed to parse keys: " # err);
  case (#ok data) data;
};

print("- transform first key");
let serialized = RSA.serializeKeys(keys);
let deserialized = RSA.deserializeKeys(serialized);
if (deserialized != keys) trap("keys don't match after trensform");

print("- transform other keys");
for (response in data.vals()) {
  let #ok(ks) = RSA.pubKeysFromJSON(response) else trap("Failed to parse keys from " # response);
  let serial = RSA.serializeKeys(ks);
  let other = RSA.deserializeKeys(serial);

  if (keys[0] != other[0]) trap("Keys don't match " # keys[0].kid # " vs " # other[0].kid);
};
