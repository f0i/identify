import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Char "mo:base/Char";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat8 "mo:base/Nat8";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Prim "mo:⛔";

module Base64 {

  public func decodeText(data : Text) : Result.Result<Text, Text> {
    let decoded : [Nat8] = switch (decode(data)) {
      case (#ok val) val;
      case (#err err) return #err(err);
    };
    let decodedBlob : Blob = Blob.fromArray(decoded);
    let ?content = Text.decodeUtf8(decodedBlob) else return #err("Faild to decode text");
    return #ok(content);
  };

  // Precomputed base64 lookup table as a constant.
  let base64Table : [Nat32] = [0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 62, 0xEE, 62, 0xEE, 63, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 0xEE, 0xEE, 0xEE, 0xEE, 63, 0xEE, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE];

  // Helper function to decode a block of 4 base64 characters into 3 bytes
  func decodeBlockOld(block : [var Nat32], output : [var Nat8], index : Nat) {
    let buffer : Nat32 = (block[0] << 18) + (block[1] << 12) + (block[2] << 6) + block[3];
    output[index] := Nat8.fromNat16(Nat16.fromNat32((buffer >> 16) & 0xFF));
    output[index + 1] := Nat8.fromNat16(Nat16.fromNat32((buffer >> 8) & 0xFF));
    output[index + 2] := Nat8.fromNat16(Nat16.fromNat32(buffer & 0xFF));
  };

  // Helper function to decode a block of 4 base64 characters into 3 bytes
  func decodeBlock(block : [var Nat32], output : [var Nat8], index : Nat) {
    let buffer : Nat32 = (block[0] << 18) + (block[1] << 12) + (block[2] << 6) + block[3];
    let (_, a, b, c) = Prim.explodeNat32(buffer);
    output[index] := a;
    output[index + 1] := b;
    output[index + 2] := c;
  };

  public func decode(data64 : Text) : Result.Result<[Nat8], Text> {
    // Prepare buffer and track state
    let base64TableSize = Array.size(base64Table);
    let paddedLength = (data64.size() + 3) / 4 * 4; // Ensure the length is a multiple of 4
    let outputSize = paddedLength * 3 / 4;
    let dataSize = data64.size() * 3 / 4;
    var output : [var Nat8] = Array.init(outputSize, 0 : Nat8);
    var block : [var Nat32] = [var 0, 0, 0, 0];
    var blockIndex : Nat = 0;
    var outIndex = 0;

    for (char in Text.toIter(data64)) {
      let c = Nat32.toNat(Char.toNat32(char));
      if (c >= base64TableSize or base64Table[c] == 0xEE) {
        return #err("Invalid base64 character " # Text.fromChar(char));
      };

      // Map character to base64 value
      block[blockIndex] := base64Table[c];
      blockIndex += 1;

      // Once we have 4 characters, decode them into 3 bytes
      if (blockIndex == 4) {
        decodeBlock(block, output, outIndex);
        outIndex += 3;
        blockIndex := 0;
      };
    };

    // Handle the remaining characters if there is padding
    if (blockIndex > 0) {
      if (blockIndex == 1) return #err("invalid length of base64 data");
      // Add padding for missing characters in the block
      for (i in Iter.range(blockIndex, 3)) {
        block[i] := 0;
      };

      decodeBlock(block, output, outIndex);
      outIndex += 3;
    };
    assert outIndex == outputSize;

    // trim and freeze array
    return #ok(Array.tabulate(dataSize, func(i : Nat) : Nat8 = output[i]));
  };

  public func decodeOld(data64 : Text) : Result.Result<[Nat8], Text> {
    // Prepare buffer and track state
    let base64TableSize = Array.size(base64Table);
    let paddedLength = (data64.size() + 3) / 4 * 4; // Ensure the length is a multiple of 4
    let outputSize = paddedLength * 3 / 4;
    let dataSize = data64.size() * 3 / 4;
    var output : [var Nat8] = Array.init(outputSize, 0 : Nat8);
    var block : [var Nat32] = [var 0, 0, 0, 0];
    var blockIndex : Nat = 0;
    var outIndex = 0;

    for (char in Text.toIter(data64)) {
      let c = Nat32.toNat(Char.toNat32(char));
      if (c >= base64TableSize or base64Table[c] == 0xEE) {
        return #err("Invalid base64 character " # Text.fromChar(char));
      };

      // Map character to base64 value
      block[blockIndex] := base64Table[c];
      blockIndex += 1;

      // Once we have 4 characters, decode them into 3 bytes
      if (blockIndex == 4) {
        decodeBlockOld(block, output, outIndex);
        outIndex += 3;
        blockIndex := 0;
      };
    };

    // Handle the remaining characters if there is padding
    if (blockIndex > 0) {
      if (blockIndex == 1) return #err("invalid length of base64 data");
      // Add padding for missing characters in the block
      for (i in Iter.range(blockIndex, 3)) {
        block[i] := 0;
      };

      decodeBlockOld(block, output, outIndex);
      outIndex += 3;
    };
    assert outIndex == outputSize;

    // trim and freeze array
    return #ok(Array.tabulate(dataSize, func(i : Nat) : Nat8 = output[i]));
  };

};
