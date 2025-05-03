import Bench "mo:bench";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Prim "mo:⛔";

module {
  public func init() : Bench.Bench {
    let bench = Bench.Bench();

    bench.name("Nat to Bytes");
    bench.description("Get bytes from Nat32");

    bench.rows(["explode", "binop"]);
    bench.cols(["1", "100", "10000"]);

    bench.runner(
      func(row, col) {
        let ?n = Nat.fromText(col) else Debug.trap("Cols must only contain numbers: " # col);

        if (row == "explode") {
          for (i in Iter.range(1, n)) {
            let buffer : Nat32 = 0x11223344;
            let (a, b, c, d) = Prim.explodeNat32(buffer);
          };
        };

        // Manual decoding (without explode)
        if (row == "binop") {
          for (i in Iter.range(1, n)) {
            let buffer : Nat32 = 0x11223344;
            let a = Nat8.fromNat16(Nat16.fromNat32((buffer >> 16) & 0xFF));
            let b = Nat8.fromNat16(Nat16.fromNat32((buffer >> 16) & 0xFF));
            let c = Nat8.fromNat16(Nat16.fromNat32((buffer >> 8) & 0xFF));
            let d = Nat8.fromNat16(Nat16.fromNat32(buffer & 0xFF));
          };
        };
      }
    );

    bench;
  };

};
