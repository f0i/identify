import { print; trap } "mo:base/Debug";
import ULEB128 "../src/backend/ULEB128";

print("# ULEB 128");

print("- encode 0");
if (ULEB128.encode(0) != [0 : Nat8]) trap("could not encode 0");

print("- encode 100");
if (ULEB128.encode(100) != [100 : Nat8]) trap("could not encode 100");

print("- encode 624485");
if (ULEB128.encode(624485) != ([0xE5, 0x8E, 0x26] : [Nat8])) trap("could not encode 624485");

print("- decode 0");
if (ULEB128.decode([0 : Nat8]) != 0) trap("could not decode 0");

print("- decode 100");
if (ULEB128.decode([100 : Nat8]) != 100) trap("could not decode 100");

print("- decode 624485");
if (ULEB128.decode([0xE5, 0x8E, 0x26] : [Nat8]) != 624485) trap("could not decode 624485");
