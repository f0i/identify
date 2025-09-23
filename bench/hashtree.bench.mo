import Bench "mo:bench";
import Time "mo:core/Time";
import Nat "mo:core/Nat";
import Text "mo:core/Text";
import HashTree "../src/backend/HashTree";
import Runtime "mo:core/Runtime";

module {
  type HashTree = HashTree.HashTree;

  public func init() : Bench.Bench {
    let bench = Bench.Bench();

    bench.name("HashTree implementations");
    bench.description("Add signatures to the sig-tree and calculate root hash");

    bench.rows(["f0i:identify"]);
    bench.cols(["1", "3", "10", "100"]);

    let time : Time.Time = 123456789_000_000_000;

    bench.runner(
      func(row, col) {
        let ?n = Nat.fromText(col) else Runtime.trap("Cols must only contain numbers: " # col);

        if (row == "f0i:identify") {
          var tree : HashTree = #Empty;
          for (i in Nat.range(0, n)) {
            let seed = Text.encodeUtf8("test" # Nat.toText(i));
            let hash : [Nat8] = [1, 2, 3, 4];
            tree := HashTree.addSig(tree, seed, hash, time + i);
          };
          assert HashTree.hash(tree) != [];
        };
      }
    );

    bench;
  };

};
