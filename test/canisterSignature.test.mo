import { print } "mo:core/Debug";
import { trap } "mo:core/Runtime";
import Principal "mo:core/Principal";
import Nat "mo:core/Nat";
import Text "mo:core/Text";
import CanisterSignature "../src/backend/CanisterSignature";
import Delegation "../src/backend/Delegation";
import Hex "mo:hex";

print("# CanisterSignature");

print("- get Principal");
let principal = CanisterSignature.toPrincipal(Principal.fromBlob("a"), "asdf");
if (Principal.toText(principal) != "alhfn-5jl5m-tarlm-awto2-if5am-guxr6-tjcra-4mxbi-olim3-vfxad-3qe") trap("Unexpected principal for a/asdf");

print("- delegation hash");
let sessionKey : [Nat8] = Hex.toArrayUnsafe("3059301306072a8648ce3d020106082a8648ce3d03010703420004b64297d1ac882642061434543d3c9600f3f59b340f8643ae0a7cd7d3f7378bd8c642cad14c00d13d4cc91487e5630f83a184c34007c019d8ec132f60475c1338");
let expiration = 1740052427100650480;

let hash = Delegation.getUnsignedHash(sessionKey, expiration, null);
let expectedHash = Hex.toArrayUnsafe("8642d484b49f9bdc791abc6b45ed980fc9328088fba97a3fa91444600d1d2e20");
if (hash != expectedHash) trap("Unexpected hash");

print("- encode public key");
let derKey = CanisterSignature.DERencodePubKey(Principal.fromBlob("a"), "asdf");
let expectedKey = Hex.toArrayUnsafe("3017300c060a2b0601040183b8430102030700016161736466");
if (derKey != expectedKey) trap("Unexpected key for a/asdf");

print("- store");
do {
  let store = CanisterSignature.newStore(principal);
  let userId = "user0";
  let origin = "test";
  let now = 1234567890_000_000_000;
  let timePerLogin = #minutes(1);
  let expireAt = 1234569890_000_000_000;
  let targets = null;
  var lastCert : Blob = "";
  let dummySetCert = func(data : Blob) = lastCert := data;

  ignore CanisterSignature.prepareDelegationTo(dummySetCert, store, userId # " " # origin, sessionKey, now, timePerLogin, expireAt, targets);

  assert store.sigExpQueue.size == 1;
  assert Text.size(debug_show store.sigTree) > 200;
  assert Text.size(debug_show store.sigTree) < 400;

  for (i in Nat.range(1, 7)) {
    ignore CanisterSignature.prepareDelegationTo(dummySetCert, store, "user" # Nat.toText(i) # " " # origin, sessionKey, now, timePerLogin, expireAt, targets);
  };

  assert store.sigExpQueue.size == 7;
  assert Text.size(debug_show store.sigTree) > 1500;
  assert Text.size(debug_show store.sigTree) < 2000;

  let now2 = now + 61_000_000_000;
  ignore CanisterSignature.prepareDelegationTo(dummySetCert, store, userId # " " # origin, sessionKey, now2, timePerLogin, expireAt, targets);

  assert store.sigExpQueue.size == 1;
  assert Text.size(debug_show store.sigTree) > 200;
  assert Text.size(debug_show store.sigTree) < 400;
};
