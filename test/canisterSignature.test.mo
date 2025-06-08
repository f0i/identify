import { print; trap } "mo:base/Debug";
import Principal "mo:base/Principal";
import CanisterSignature "../src/backend/CanisterSignature";
import Delegation "../src/backend/Delegation";
import Hex "../src/backend/Hex";

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
