import { print } "mo:core/Debug";
import Delegation "../src/backend/Delegation";
import Hex "mo:hex";

print("# Delegation");

print("- unsigned bytes epoch");

let unsigned = Delegation.getUnsignedBytes([1, 2, 3], 0, null);
let expected = Hex.toArrayUnsafe "1a69632d726571756573742d617574682d64656c65676174696f6e6ccc91d777f1a2b156834c0f8b879f3cdc0a57ecef1dd80f1e1a9f2129b082a0";
assert (unsigned == expected);

print("- unsigned bytes with time");
let unsigned2 = Delegation.getUnsignedBytes([1, 2, 3], 1234567890123123123, null);
let expected2 = Hex.toArrayUnsafe "1a69632d726571756573742d617574682d64656c65676174696f6ede1a11ae8abd061420577a3432df95c57ef9c1731247b2a62253503e9688a835";
assert (unsigned2 == expected2);
