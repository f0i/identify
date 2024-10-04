import Nat8 "mo:base/Nat8";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";

module {
  // Encode a Nat into ULEB128
  public func encode(value : Nat) : [Nat8] {
    if (value == 0) {
      // Special case: if the number is zero, encode it as a single zero byte
      return [0x00];
    };

    var n = value;
    var result : Buffer.Buffer<Nat8> = Buffer.Buffer<Nat8>(12);

    // Keep encoding 7 bits at a time
    while (n != 0) {
      var byte = Nat8.fromNat(n % 128); // Extract the lowest 7 bits
      n := n / 128; // Shift the number right by 7 bits

      if (n != 0) {
        byte := byte | 0x80; // Set the MSB to 1 if more bytes follow
      };

      result.add(byte);
    };

    return Buffer.toArray(result);
  };

  // Decode ULEB128 into a Nat
  public func decode(bytes : [Nat8]) : Nat {
    var result : Nat = 0;
    var shift : Nat = 1;

    label forloop for (byte in bytes.vals()) {
      let value = byte & 0x7F; // Get the 7 bits
      result += (Nat8.toNat(value) * shift); // Add the bits to result
      shift *= 128; // Move to the next 7-bit slot

      // If the MSB is 0, this was the last byte
      if ((byte & 0x80) == 0) {
        break forloop;
      };
    };

    return result;
  };
};
