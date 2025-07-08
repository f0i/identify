import { print; trap } "mo:base/Debug";
import { transformBody } "../src/backend/certs/GoogleCert";
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
let transformed = transformBody(data[0], #keepAll);
switch (RSA.pubKeysFromJSON(data[0])) {
  case (#err err) trap("failed to parse keys: " # err);
  case (#ok data) if (data != keys) trap("keys don't match after trensform");
};

print("- transform other keys");
for (response in data.vals()) {
  let other = transformBody(response, #ignoreNofM(1, 3));
  if (other != transformed) trap("Keys don't match:\n" # transformed # "\n\n\n" # other);
};
