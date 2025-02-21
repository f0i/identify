import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Char "mo:base/Char";
import Nat8 "mo:base/Nat8";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Text "mo:base/Text";

/// Function to convert between hex and byte arrays
module {

  /// Access elements of an iterator two at a time
  /// If `iter` contains an odd number of elements, the last one is discarded
  public func pairs<T>(iter : Iter.Iter<T>) : Iter.Iter<(T, T)> {

    func next() : ?(T, T) {
      switch (iter.next(), iter.next()) {
        case (?a, ?b) { return ?(a, b) };
        case (_, _) { return null };
      };
    };

    return { next };
  };

  /// Convert a byte array to hex Text
  public func toText(bytes : [Nat8]) : Text {
    var out = "";
    for (byte in bytes.vals()) {
      out := out # encodeByte(byte);
    };
    return out;
  };

  /// Convert an array of byte arrays to hex Text
  public func toText2D(bytess : [[Nat8]]) : Text {
    let texts = Array.map(bytess, toText);
    return "[" # Text.join(", ", texts.vals()) # "]";
  };

  /// Convert hex Text into a byte array
  public func toArray(hex : Text) : Result.Result<[Nat8], Text> {
    let chars = hex.size();

    let size = if (chars % 2 == 0) { chars / 2 } else { chars / 2 + 1 };

    var arr = Array.init<Nat8>(size, 0);
    var i = 0;
    for ((high, low) in pairs(hex.chars())) {
      switch (decodeNibble(high), decodeNibble(low)) {
        case (?a, ?b) { arr[i] := (a * 16) + b };
        case (_, _) {
          return #err("Invalid byte: " # Char.toText(high) # Char.toText(low));
        };
      };
      i += 1;
    };
    return #ok(Array.freeze(arr));
  };

  /// Convert hex Text into a byte array
  /// Similar to `toArray` but traps if `hex` contains invalid characters
  public func toArrayUnsafe(hex : Text) : [Nat8] {
    switch (toArray(hex)) {
      case (#ok(data)) return data;
      case (#err(msg)) Debug.trap("Hex.toArrayUnsafe: " # msg);
    };
  };

  /// Decode a single hex character
  func decodeNibble(c : Char) : ?Nat8 {
    switch (c) {
      case ('0') { ?0 };
      case ('1') { ?1 };
      case ('2') { ?2 };
      case ('3') { ?3 };
      case ('4') { ?4 };
      case ('5') { ?5 };
      case ('6') { ?6 };
      case ('7') { ?7 };
      case ('8') { ?8 };
      case ('9') { ?9 };
      case ('a') { ?10 };
      case ('b') { ?11 };
      case ('c') { ?12 };
      case ('d') { ?13 };
      case ('e') { ?14 };
      case ('f') { ?15 };
      case ('A') { ?10 };
      case ('B') { ?11 };
      case ('C') { ?12 };
      case ('D') { ?13 };
      case ('E') { ?14 };
      case ('F') { ?15 };
      case (_) { null };
    };
  };

  /// Encode a byte into hex Text containing exactly two hex characters
  func encodeByte(byte : Nat8) : Text {
    return encodeNibble(byte / 16) # encodeNibble(byte % 16);
  };

  /// Encode a nibble into a single hex character
  func encodeNibble(nibble : Nat8) : Text {
    switch (nibble) {
      case (0) { "0" };
      case (1) { "1" };
      case (2) { "2" };
      case (3) { "3" };
      case (4) { "4" };
      case (5) { "5" };
      case (6) { "6" };
      case (7) { "7" };
      case (8) { "8" };
      case (9) { "9" };
      case (10) { "a" };
      case (11) { "b" };
      case (12) { "c" };
      case (13) { "d" };
      case (14) { "e" };
      case (15) { "f" };
      case (_) {
        Debug.trap("invalid value in encodeNibble: " # Nat8.toText(nibble));
      };
    };
  };

};
