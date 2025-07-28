import Bench "mo:bench";
import Nat "mo:core/Nat";
import Nat8 "mo:core/Nat8";
import Nat16 "mo:core/Nat16";
import Nat32 "mo:core/Nat32";
import Runtime "mo:core/Runtime";

module {
  public func init() : Bench.Bench {
    let bench = Bench.Bench();

    bench.name("Nat to Bytes");
    bench.description("Get bytes from Nat32");

    bench.rows(["explode", "binop"]);
    bench.cols(["1", "100", "10000"]);

    bench.runner(
      func(row, col) {
        let ?n = Nat.fromText(col) else Runtime.trap("Cols must only contain numbers: " # col);

        if (row == "explode") {
          for (i in Nat.range(0, n)) {
            let buffer : Nat32 = 0x11223344;
            let (a, b, c, d) = Nat32.explode(buffer);
          };
        };

        // Manual decoding (without explode)
        if (row == "binop") {
          for (i in Nat.range(0, n)) {
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
